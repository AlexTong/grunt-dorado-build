dorado.widgetConfig = (id, config) ->
	if arguments.length == 1
		if typeof id == "string"
			return dorado._widgetConfig?[id]
		else
			config = id
			@widgetConfig(k, v) for k, v of config
	else
		dorado._widgetConfig ?= {}
		dorado._widgetConfig[id] = config
	return

dorado._userDomCompiler.widget = () -> return

ALIAS_REGEXP = new RegExp("\\$default", "g")

dorado._userDomCompiler.$.push((scope, dom, context) ->
	return null if dorado.util.userData(dom, dorado.constants.DOM_ELEMENT_KEY)

	if dom.id
		jsonConfig = dorado._widgetConfig?[dom.id]

	configKey = dom.getAttribute("widget-config")
	if configKey
		dom.removeAttribute("widget-config")
		config = context.widgetConfigs?[configKey]
	else
		widgetConfigStr = dom.getAttribute("d-widget")
		if widgetConfigStr
			dom.removeAttribute("d-widget")
			if context.defaultPath
				widgetConfigStr = widgetConfigStr.replace(ALIAS_REGEXP, context.defaultPath)
			config = dorado.util.parseStyleLikeString(widgetConfigStr, "$type")

	return null unless config or jsonConfig

	config ?= {}
	if jsonConfig
		config[k] = v for k, v of jsonConfig

	oldParentConstr = context.constr
	constr = dorado.resolveType((oldParentConstr?.CHILDREN_TYPE_NAMESPACE or "widget"), config, dorado.Widget)
	config.$constr = context.constr = constr

	return (scope, dom) ->
		context.constr = oldParentConstr
		config.dom = dom
		oldScope = dorado.currentScope
		dorado.currentScope = scope
		try
			widget = dorado.widget(config)
			return widget
		finally
			dorado.currentScope = oldScope
)

dorado.registerTypeResolver "widget", (config) ->
	return unless config and config.$type
	return dorado[dorado.util.capitalize(config.$type)]

dorado.registerType("widget", "_default", dorado.Widget)

dorado.widget = (config, namespace) ->
	return null unless config
	if typeof config == "string"
		ele = window[config]
		return null unless ele
		if ele.nodeType
			widget = dorado.util.userData(ele, dorado.constants.DOM_ELEMENT_KEY)
			return if widget instanceof dorado.Widget then widget else null
		else
			group = []
			for e in ele
				widget = dorado.util.userData(e, dorado.constants.DOM_ELEMENT_KEY)
				group.push(widget) if widget instanceof dorado.Widget
			return if group.length then dorado.Element.createGroup(group) else null
	else
		if config instanceof Array
			group = []
			for c in config
				group.push(dorado.widget(c))
			return dorado.Element.createGroup(group)
		else if config.nodeType == 1
			widget = dorado.util.userData(config, dorado.constants.DOM_ELEMENT_KEY)
			return if widget instanceof dorado.Widget then widget else null
		else
			constr = config.$constr or dorado.resolveType(namespace or "widget", config, dorado.Widget)
			return new constr(config)

dorado.findWidget = (dom, type) ->
	if type and typeof type == "string"
		type = dorado.resolveType("widget", { $type: type })
		return null unless type

	while dom
		widget = dorado.util.userData(dom, dorado.constants.DOM_ELEMENT_KEY)
		if widget
			if not type or widget instanceof type
				return widget
		dom = dom.parentNode
	return null

TEMP_TEMPLATE = null

dorado.TemplateSupport =
	destroy: () ->
		if @_templates
			delete @_templates[name] for name of @_templates
		return

	_parseTemplates: () ->
		return unless @_dom
		child = @_dom.firstChild
		while child
			if child.nodeName == "TEMPLATE"
				@_regTemplate(child)
			child = child.nextSibling
		@_regDefaultTempaltes()
		return

	_trimTemplate: (dom) ->
		child = dom.firstChild
		while child
			next = child.nextSibling
			if child.nodeType == 3
				if $.trim(child.nodeValue) == ""
					dom.removeChild(child)
			child = next
		return

	_regTemplate: (name, template) ->
		if arguments.length == 1
			template = name
			if template.nodeType
				name = template.getAttribute("name")
			else
				name = template.name
		@_templates ?= {}
		@_templates[name or "default"] = template
		return

	_regDefaultTempaltes: () ->
		for name, template of @constructor.TEMPLATES
			if @_templates?.hasOwnProperty(name) or !template
				continue
			@_regTemplate(name, template)
		return

	_getTemplate: (name = "default", defaultName) ->
		return null unless @_templates
		template = @_templates[name]
		if !template and defaultName
			name = defaultName
			template = @_templates[name]

		if template and !template._trimed
			if template.nodeType
				if template.nodeName == "TEMPLATE"
					if !template.firstChild
						html = template.innerHTML
						if html
							TEMP_TEMPLATE ?= document.createElement("div")
							template = TEMP_TEMPLATE
							template.innerHTML = html
					@_trimTemplate(template)
					if template.firstChild == template.lastChild
						template = template.firstChild
					else
						templs = []
						child = template.firstChild
						while child
							templs.push(child)
							child = child.nextSibling
						template = templs
				@_templates[name] = template
			else
				@_doms ?= {}
				template = $.xCreate(template, @_doms)
				if @_doms.widgetConfigs
					@_templateContext ?= {}
					if @_templateContext.widgetConfigs
						widgetConfigs = @_templateContext.widgetConfigs
						for k, c of @_doms.widgetConfigs
							widgetConfigs[k] = c
					else
						@_templateContext.widgetConfigs = @_doms.widgetConfigs
				@_templates[name] = template
			template._trimed = true

		return template

	_cloneTemplate: (template, supportMultiNodes) ->
		if template instanceof Array
			if supportMultiNodes
				return (templ.cloneNode(true) for templ in template)
			else
				return template[0].cloneNode(true)
		else
			return template.cloneNode(true)

dorado.DataWidgetMixin =
	_bindSetter: (bindStr) ->
		return if @_bindStr == bindStr

		if @_bindInfo
			bindInfo = @_bindInfo
			if @_watchingPaths
				for path in @_watchingPaths
					@_scope.data.unbind(path.join("."), @_bindProcessor)
			delete @_bindInfo

		@_bindStr = bindStr

		if bindStr and @_scope
			@_bindInfo = bindInfo = {}

			bindInfo.expression = expression = dorado._compileExpression(bindStr)
			if expression.repeat or expression.setAlias
				throw new dorado.I18nException("dorado.error.needSimpleBinding", bindStr)
			bindInfo.isWriteable = (expression.type == "MemberExpression" or expression.type == "Identifier") and
					not expression.hasCallStatement and not expression.convertors

			if !@_bindProcessor
				@_bindProcessor = bindProcessor = {
					_processMessage: (bindingPath, path, type, arg) =>
						if @_filterDataMessage
							if !@_filterDataMessage(path, type, arg)
								return
						else
							unless dorado.constants.MESSAGE_REFRESH <= type <= dorado.constants.MESSAGE_CURRENT_CHANGE or @_watchingMoreMessage
								return

						if @_bindInfo.watchingMoreMessage
							dorado.util.delay(@, "processMessage", 100, () ->
								if @_processDataMessage
									@_processDataMessage(@_bindInfo.watchingPaths[0],
										dorado.constants.MESSAGE_REFRESH, {})
								else
									@_refreshBindingValue()
								return
							)
						else
							if @_processDataMessage
								@_processDataMessage(path, type, arg)
							else
								@_refreshBindingValue()
						return
				}

			path = expression.path
			if !path
				if expression.hasCallStatement
					path = "**"
					bindInfo.watchingMoreMessage = expression.hasCallStatement or expression.convertors
			else
				if typeof expression.path == "string"
					bindInfo.expressionPaths = [expression.path.split(".")]
				if expression.path instanceof Array
					paths = []
					for p in expression.path
						paths.push(p.split("."))
					bindInfo.expressionPaths = paths

			if path
				if typeof path == "string"
					paths = [path]
				else
					paths = path

				@_watchingPaths = paths
				for p, i in paths
					@_scope.data.bind(p, bindProcessor)
					paths[i] = p.split(".")

				if @_processDataMessage
					@_processDataMessage(null, dorado.constants.MESSAGE_REFRESH, {})
				else
					@_refreshBindingValue()
		return

	destroy: () ->
		if @_watchingPaths
			for path in @_watchingPaths
				@_scope.data.unbind(path.join("."), @_bindProcessor)
		return

	_readBindingValue: (dataCtx) ->
		return unless @_bindInfo?.expression
		dataCtx ?= {}
		return @_bindInfo.expression.evaluate(@_scope, "auto", dataCtx)

	_writeBindingValue: (value) ->
		return unless @_bindInfo?.expression
		if !@_bindInfo.isWriteable
			throw new dorado.I18nException("dorado.error.bindingNotWritable", @_bindStr)
		@_scope.set(@_bindStr, value)
		return

	_getBindingDataType: () ->
		return unless @_bindInfo?.expression and @_bindInfo.isWriteable
		return @_scope.data.getDataType(@_bindStr)
		return

	_isRootOfTarget: (changedPath, targetPath) ->
		if !changedPath or !targetPath then return true
		if targetPath instanceof Array
			targetPaths = targetPath
			for targetPath in targetPaths
				isRoot = true
				for part, i in changedPath
					if part != targetPath[i]
						isRoot = false
						break
				if isRoot then return true
			return false
		else
			for part, i in changedPath
				if part != targetPath[i]
					return false
			return true

dorado.DataItemsWidgetMixin =
	_alias: "item"

	_bindSetter: (bindStr) ->
		return if @_bindStr == bindStr

		@_bindStr = bindStr

		if bindStr and @_scope
			expression = dorado._compileExpression(bindStr, "repeat")
			if !expression.repeat
				throw new dorado.I18nException("dorado.error.needRepeatBinding", bindStr)
			@_alias = expression.alias
		@_itemsScope.setExpression(expression)
		return

	constructor: () ->
		@_itemsScope = itemsScope = new dorado.ItemsScope(@_scope)

		itemsScope.onItemsRefresh = (arg) => @_onItemsRefresh(arg)
		itemsScope.onItemRefresh = (arg) => @_onItemRefresh(arg)
		itemsScope.onItemInsert = (arg) => @_onItemInsert(arg)
		itemsScope.onItemRemove = (arg) => @_onItemRemove(arg)
		if @_onCurrentItemChange
			itemsScope.onCurrentItemChange = (arg) => @_onCurrentItemChange(arg)

	_getItems: () ->
		if !@_itemsRetrieved
			@_itemsRetrieved = true
			@_itemsScope.retrieveItems()
		return {
		items: @_itemsScope.items
		originItems: @_itemsScope.originItems
		}