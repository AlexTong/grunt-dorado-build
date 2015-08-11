###
BindingFeature
###

class dorado._BindingFeature
	constructor: (@expression) ->
		if @expression
			@path = @expression.path
			if !@path and @expression.hasCallStatement
				@path = "**"
				@delay = true
			@watchingMoreMessage = @expression.hasCallStatement or @expression.convertors

	init: () ->
		return

	evaluate: (domBinding, dataCtx) ->
		dataCtx ?= {}
		return @expression.evaluate(domBinding.scope, "auto", dataCtx)

	refresh: (domBinding, force) ->
		return unless @_refresh
		if @delay and !force
			dorado.util.delay(@, "refresh", 100, () ->
				@_refresh(domBinding)
				return
			)
		else
			@_refresh(domBinding)
		return

class dorado._EventFeature extends dorado._BindingFeature
	constructor: (@expression, @event) ->

	init: (domBinding) ->
		expression = @expression
		domBinding.$dom.bind(@event, () ->
			oldScope = dorado.currentScope
			dorado.currentScope = domBinding.scope
			try
				return expression.evaluate(domBinding.scope, "never")
			finally
				dorado.currentScope = oldScope
		)
		return

class dorado._AliasFeature extends dorado._BindingFeature
	constructor: (expression) ->
		super(expression)
		@alias = expression.alias

	init: (domBinding) ->
		domBinding.scope = new dorado.AliasScope(domBinding.scope, @expression)
		domBinding.subScopeCreated = true
		return

	_processMessage: (domBinding, bindingPath, path, type, arg)->
		if dorado.constants.MESSAGE_REFRESH <= type <= dorado.constants.MESSAGE_CURRENT_CHANGE or @watchingMoreMessage
			@refresh(domBinding)
		return

	_refresh: (domBinding)->
		data = @evaluate(domBinding)
		domBinding.scope.data.setTargetData(data)
		return

class dorado._RepeatFeature extends dorado._BindingFeature
	constructor: (expression) ->
		super(expression)
		@alias = expression.alias

	init: (domBinding) ->
		domBinding.scope = scope =  new dorado.ItemsScope(domBinding.scope, @expression)

		scope.onItemsRefresh = () =>
			@onItemsRefresh(domBinding)
			return
		scope.onCurrentItemChange = (arg) ->
			$fly(domBinding.currentItemDom).removeClass(dorado.constants.COLLECTION_CURRENT_CLASS) if domBinding.currentItemDom
			if arg.current and domBinding.itemDomBindingMap
				itemId = dorado.Entity._getEntityId(arg.current)
				if itemId
					currentItemDomBinding = domBinding.itemDomBindingMap[itemId]
					$fly(currentItemDomBinding.dom).addClass(dorado.constants.COLLECTION_CURRENT_CLASS) if currentItemDomBinding
			domBinding.currentItemDom = currentItemDomBinding.dom
			return
		scope.onItemInsert = (arg) =>
			headDom = domBinding.dom
			tailDom = dorado.util.userData(headDom, dorado.constants.REPEAT_TAIL_KEY)
			templateDom = dorado.util.userData(headDom, dorado.constants.REPEAT_TEMPLATE_KEY)
			itemDom = @createNewItem(domBinding, templateDom, domBinding.scope, arg.entity)
			insertMode = arg.insertMode
			if !insertMode or insertMode == "end"
				$fly(tailDom).before(itemDom)
			else if insertMode == "begin"
				$fly(headDom).after(itemDom)
			else if domBinding.itemDomBindingMap
				refEntityId = dorado.Entity._getEntityId(arg.refEntity)
				if refEntityId
					refDom = domBinding.itemDomBindingMap[refEntityId]?
					if refDom
						if insertMode == "before"
							$fly(refDom).before(itemDom)
						else
							$fly(refDom).after(itemDom)
			return
		scope.onItemRemove = (arg) ->
			itemId = dorado.Entity._getEntityId(arg.entity)
			if itemId
				itemDomBinding = domBinding.itemDomBindingMap[itemId]
				if itemDomBinding
					arg.itemsScope.unregItemScope(itemId)
					itemDomBinding.remove()
					delete domBinding.currentItemDom if itemDomBinding.dom == domBinding.currentItemDom
			return

		domBinding.subScopeCreated = true
		return

	_refresh: (domBinding) ->
		domBinding.scope.refreshItems()
		return

	onItemsRefresh: (domBinding) ->
		scope = domBinding.scope

		items = scope.items
		originItems = scope.originData

		if items and !(items instanceof dorado.EntityList) and !(items instanceof Array)
			throw new dorado.I18nException("dorado.error.repeatNeedCollection", @expression)

		if items != domBinding.items or (items and items.timestamp != domBinding.timestamp)
			domBinding.items = items
			domBinding.timestamp = items?.timestamp or 0

			headDom = domBinding.dom
			tailDom = dorado.util.userData(headDom, dorado.constants.REPEAT_TAIL_KEY)
			templateDom = dorado.util.userData(headDom, dorado.constants.REPEAT_TEMPLATE_KEY)
			if !tailDom
				tailDom = document.createComment("Repeat Tail ")
				$fly(headDom).after(tailDom)
				dorado.util.userData(headDom, dorado.constants.REPEAT_TAIL_KEY, tailDom)
			currentDom = headDom

			documentFragment = null
			if items
				domBinding.itemDomBindingMap = {}
				scope.resetItemScopeMap()

				$fly(domBinding.currentItemDom).removeClass(dorado.constants.COLLECTION_CURRENT_CLASS) if domBinding.currentItemDom
				dorado.each items, (item) =>
					if !item? then return

					itemDom = currentDom.nextSibling
					if itemDom == tailDom then itemDom = null

					if itemDom
						itemDomBinding = dorado.util.userData(itemDom, dorado.constants.DOM_BINDING_KEY)
						itemScope = itemDomBinding.scope
						if typeof item == "object"
							itemId = dorado.Entity._getEntityId(item)
						else
							itemId = dorado.uniqueId()
						scope.regItemScope(itemId, itemScope)
						itemDomBinding.itemId = itemId
						domBinding.itemDomBindingMap[itemId] = itemDomBinding
						itemScope.data.setTargetData(item)
					else
						itemDom = @createNewItem(domBinding, templateDom, scope, item)
						documentFragment ?= document.createDocumentFragment()
						documentFragment.appendChild(itemDom)
						$fly(tailDom).before(itemDom)

					if item == (items.current or originItems?.current)
						$fly(itemDom).addClass(dorado.constants.COLLECTION_CURRENT_CLASS)
						domBinding.currentItemDom = itemDom

					currentDom = itemDom
					return

			if !documentFragment
				itemDom = currentDom.nextSibling
				while itemDom and itemDom != tailDom
					currentDom = itemDom
					itemDom = currentDom.nextSibling
					$fly(currentDom).remove()
			else
				$fly(tailDom).before(documentFragment)
		return

	createNewItem: (repeatDomBinding, templateDom, scope, item) ->
		itemScope = new dorado.ItemScope(scope, @alias)
		itemScope.data.setTargetData(item, true)

		itemDom = templateDom.cloneNode(true)

		@deepCloneNodeData(itemDom, itemScope, false)
		templateDomBinding = dorado.util.userData(templateDom, dorado.constants.DOM_BINDING_KEY)
		domBinding = templateDomBinding.clone(itemDom, itemScope)
		@refreshItemDomBinding(itemDom, itemScope)

		if typeof item == "object"
			itemId = dorado.Entity._getEntityId(item)
		else
			itemId = dorado.uniqueId()
		scope.regItemScope(itemId, itemScope)
		domBinding.itemId = itemId
		repeatDomBinding.itemDomBindingMap[itemId] = domBinding
		return itemDom

	deepCloneNodeData: (node, scope, cloneDomBinding) ->
		store = dorado.util.userData(node)
		if store
			clonedStore = {}
			for k, v of store
				if k == dorado.constants.DOM_BINDING_KEY
					if cloneDomBinding
						v = v.clone(node, scope)
				else if k.substring(0, 2) == "__"
					continue
				clonedStore[k] = v
			dorado.util.userData(node, clonedStore)

		child = node.firstChild
		while child
			if child.nodeType != 3 and !child.hasAttribute?(dorado.constants.IGNORE_DIRECTIVE)
				@deepCloneNodeData(child, scope, true)
			child = child.nextSibling
		return

	refreshItemDomBinding: (dom, itemScope) ->
		domBinding = dorado.util.userData(dom, dorado.constants.DOM_BINDING_KEY)
		if domBinding
			domBinding.refresh()
			itemScope = domBinding.subScope or domBinding.scope
			if domBinding instanceof dorado._RepeatDomBinding
				currentDom = dorado.util.userData(domBinding.dom, dorado.constants.REPEAT_TAIL_KEY)

		child = dom.firstChild
		while child
			if child.nodeType != 3 and !child.hasAttribute?(dorado.constants.IGNORE_DIRECTIVE)
				child = @refreshItemDomBinding(child, itemScope)
			child = child.nextSibling

		initializers = dorado.util.userData(dom, dorado.constants.DOM_INITIALIZER_KEY)
		if initializers
			initializer(itemScope, dom) for initializer in initializers
			dorado.util.removeUserData(dom, dorado.constants.DOM_INITIALIZER_KEY)
		return currentDom or dom

class dorado._DomFeature extends dorado._BindingFeature
	writeBack: (domBinding, value) ->
		path = @path
		if path and typeof path == "string"
			@ignoreMessage = true
			domBinding.scope.set(path, value)
			@ignoreMessage = false
		return

	_processMessage: (domBinding, bindingPath, path, type, arg)->
		if dorado.constants.MESSAGE_REFRESH <= type <= dorado.constants.MESSAGE_CURRENT_CHANGE or @watchingMoreMessage
			@refresh(domBinding)
		return

	_refresh: (domBinding)->
		return if @ignoreMessage
		value = @evaluate(domBinding)
		@_doRefresh(domBinding, value)
		return

class dorado._TextNodeFeature extends dorado._DomFeature
	_doRefresh: (domBinding, value) ->
		$fly(domBinding.dom).text(if !value? then "" else value)
		return

class dorado._DomAttrFeature extends dorado._DomFeature
	constructor: (expression, @attr, @isStyle) ->
		super(expression)

	_doRefresh: (domBinding, value) ->
		attr = @attr
		if attr == "text"
			domBinding.$dom.text(if !value? then "" else value)
		else if attr == "html"
			domBinding.$dom.html(if !value? then "" else value)
		else if @isStyle
			domBinding.$dom.css(attr, value)
		else
			domBinding.$dom.attr(attr, if !value? then "" else value)
		return

class dorado._DomClassFeature extends dorado._DomFeature
	constructor: (expression, @className) ->
		super(expression)

	_doRefresh: (domBinding, value) ->
		domBinding.$dom[if value then "addClass" else "removeClass"](@className)
		return

class dorado._TextBoxFeature extends dorado._DomFeature
	init: (domBinding) ->
		feature = @
		domBinding.$dom.on "input", () ->
			feature.writeBack(domBinding, @value)
			return
		super()
		return

	_doRefresh: (domBinding, value)->
		domBinding.dom.value = value or ""
		return

class dorado._CheckboxFeature extends dorado._DomFeature
	init: (domBinding) ->
		feature = @
		domBinding.$dom.on("click", () ->
			feature.writeBack(domBinding, @checked)
			return
		)
		super()
		return

	_doRefresh: (domBinding, value)->
		checked = dorado.DataType.defaultDataTypes.boolean.parse(value)
		domBinding.dom.checked = checked
		return

class dorado._RadioFeature extends dorado._DomFeature
	init: (domBinding) ->
		domBinding.$dom.on("click", () ->
			checked = this.checked
			if checked then @writeBack(domBinding, checked)
			return
		)
		super()
		return

	_doRefresh: (domBinding, value)->
		domBinding.dom.checked = (value == domBinding.dom.value)
		return

class dorado._SelectFeature extends dorado._DomFeature
	init: (domBinding) ->
		feature = @
		domBinding.$dom.on("change", () ->
			value = @options[@selectedIndex]
			feature.writeBack(domBinding, value?.value)
			return
		)
		super()
		return

	_doRefresh: (domBinding, value)->
		domBinding.dom.value = value
		return

class dorado._DisplayFeature extends dorado._DomFeature
	_doRefresh: (domBinding, value)->
		domBinding.$dom[if value then "show" else "hide"]()
		return

class dorado._SelectOptionsFeature extends dorado._DomFeature
	_doRefresh: (domBinding, optionValues)->
		return unless optionValues instanceof Array or optionValues instanceof dorado.EntityList

		options = domBinding.dom.options
		if optionValues instanceof dorado.EntityList
			options.length = optionValues.entityCount
		else
			options.length = optionValues.length

		dorado.each optionValues, (optionValue, i) ->
			option = options[i]
			if dorado.util.isSimpleValue(optionValue)
				$fly(option).removeAttr("value").text(optionValue)
			else if optionValue instanceof dorado.Entity
				$fly(option).attr("value", optionValue.get("value") or optionValue.get("key")).text(optionValue.get("text") or optionValue.get("name"))
			else
				$fly(option).attr("value", optionValue.value or optionValue.key).text(optionValue.text or optionValue.name)
			return
		return