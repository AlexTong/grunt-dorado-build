IGNORE_NODES = ["SCRIPT", "STYLE", "META", "TEMPLATE"]
ALIAS_REGEXP = new RegExp("\\$default", "g")

dorado._mainInitFuncs = []

dorado._rootFunc = () ->
	fn = null
	targetDom = null
	modelName = null
	for arg in arguments
		if typeof arg == "function"
			fn = arg
		else if typeof arg == "string"
			modelName = arg
		else if arg?.nodeType or typeof arg == "object" and arg.length > 0
			targetDom = arg

	init = (dom, model, param) ->
		oldScope = dorado.currentScope
		dorado.currentScope = model
		try
			fn?(model, param)

			if !dom
				viewDoms = document.getElementsByClassName(dorado.constants.VIEW_CLASS)
				if viewDoms?.length then dom = viewDoms
			dom ?= document.body

			if dom.length
				doms = dom
				for dom in doms
					dorado._renderDomTemplate(dom, model)
			else
				dorado._renderDomTemplate(dom, model)
		finally
			dorado.currentScope = oldScope
		return

	if dorado._suspendedInitFuncs
		dorado._suspendedInitFuncs.push(init)
	else
		modelName ?= dorado.constants.DEFAULT_PATH
		model = dorado.model(modelName)
		model ?= new dorado.Model(modelName)

		if dorado._mainInitFuncs
			dorado._mainInitFuncs.push(
				targetDom: targetDom
				model: model
				init: init
			)
		else
			init(targetDom, model)
	return dorado

$ () ->
	initFuncs = dorado._mainInitFuncs
	delete dorado._mainInitFuncs
	for initFunc in initFuncs
		initFunc.init(initFunc.targetDom, initFunc.model)

	if dorado.getListeners("ready")
		dorado.fire("ready", dorado)
		dorado.off("ready")
	return

dorado._userDomCompiler =
	$: []

$.xCreate.templateProcessors.push (template) ->
	if template instanceof dorado.Widget
		dom = template.getDom()
		dom.setAttribute(dorado.constants.IGNORE_DIRECTIVE, "")
		return dom
	return

$.xCreate.attributeProcessor["d-widget"] = ($dom, attrName, attrValue, context) ->
	return unless attrValue
	if typeof attrValue == "string"
		$dom.attr(attrName, attrValue)
	else if context
		configKey = dorado.uniqueId()
		$dom.attr("widget-config", configKey)
		widgetConfigs = context.widgetConfigs
		if !widgetConfigs
			context.widgetConfigs = widgetConfigs = {}
		widgetConfigs[configKey] = attrValue
	return

dorado.xRender = (template, model, context) ->
	return unless template

	if template.nodeType
		dom = template
	else if typeof template == "string"
		documentFragment = document.createDocumentFragment()
		div = document.createElement("div")
		div.innerHTML = template
		child = div.firstChild
		while child
			documentFragment.appendChild(child)
			child = child.nextSibling
		div = null
	else
		oldScope = dorado.currentScope
		dorado.currentScope = model
		try
			context ?= {}
			if template instanceof Array
				documentFragment = document.createDocumentFragment()
				for node in template
					if node.tagName
						child = $.xCreate(node, context)
					else
						if node instanceof dorado.Widget
							widget = node
						else
						widget = dorado.widget(node, context.namespace)
						child = widget.getDom()
						child.setAttribute(dorado.constants.IGNORE_DIRECTIVE, "")
					documentFragment.appendChild(child)
			else
				if template.tagName
					dom = $.xCreate(template, context)
				else
					if template instanceof dorado.Widget
						widget = template
					else
						widget = dorado.widget(template, context.namespace)
					dom = widget.getDom()
					dom.setAttribute(dorado.constants.IGNORE_DIRECTIVE, "")
		finally
			dorado.currentScope = oldScope

	if dom
		dorado._renderDomTemplate(dom, model, context)
	else if documentFragment
		dorado._renderDomTemplate(documentFragment, model, context)

		if documentFragment.firstChild == documentFragment.lastChild
			dom = documentFragment.firstChild
		else
			dom = documentFragment
	return dom

dorado._renderDomTemplate = (dom, scope, context = {}) ->
	_doRrenderDomTemplate(dom, scope, context)
	return

_doRrenderDomTemplate = (dom, scope, context) ->
	return dom if dom.nodeType == 8
	return dom if dom.nodeType == 1 and dom.hasAttribute(dorado.constants.IGNORE_DIRECTIVE)
	return dom if IGNORE_NODES.indexOf(dom.nodeName) > -1

	if dom.nodeType == 3 # #text
		bindingExpr = dom.nodeValue
		parts = dorado._compileText(bindingExpr)
		buildContent(parts, dom, scope) if parts?.length
		return dom
	else if dom.nodeType == 11 # #documentFragment
		child = dom.firstChild
		while child
			child = _doRrenderDomTemplate(child, scope, context)
			child = child.nextSibling
		return dom

	initializers = null
	features = null
	removeAttrs = null

	bindingExpr = dom.getAttribute("d-repeat")
	if bindingExpr
		bindingExpr = bindingExpr.replace(ALIAS_REGEXP, context.defaultPath)
		dom.removeAttribute("d-repeat")
		expression = dorado._compileExpression(bindingExpr, "repeat")
		if expression
			bindingType = "repeat"
			feature = buildRepeatFeature(expression)
			features ?= []
			features.push(feature)
	else
		bindingExpr = dom.getAttribute("d-alias")
		if bindingExpr
			bindingExpr = bindingExpr.replace(ALIAS_REGEXP, context.defaultPath)
			dom.removeAttribute("d-alias")
			bindingType = "alias"
			expression = dorado._compileExpression(bindingExpr, "alias")
			if expression
				feature = buildAliasFeature(expression)
				features ?= []
				features.push(feature)

	bindingExpr = dom.getAttribute("d-bind")
	if bindingExpr
		bindingExpr = bindingExpr.replace(ALIAS_REGEXP, context.defaultPath)
		dom.removeAttribute("d-bind")
		expression = dorado._compileExpression(bindingExpr)
		if expression
			feature = buildBindFeature(expression, dom)
			features ?= []
			features.push(feature)

	for attr in dom.attributes
		attrName = attr.name
		if attrName.substring(0, 2) == "d-"
			removeAttrs ?= []
			removeAttrs.push(attrName)

			attrValue = attr.value
			if attrValue and context.defaultPath
				attrValue = attrValue.replace(ALIAS_REGEXP, context.defaultPath)

			attrName = attrName.substring(2)
			if attrName == "style"
				newFeatures = buildStyleFeature(attrValue)
				features = if features then features.concat(newFeatures) else newFeatures
			else if attrName == "class"
				newFeatures = buildClassFeature(attrValue)
				features = if features then features.concat(newFeatures) else newFeatures
			else
				customDomCompiler = dorado._userDomCompiler[attrName]
				if customDomCompiler
					result = customDomCompiler(scope, dom, context)
					if result
						if result instanceof dorado._BindingFeature
							features.push(result)
						if typeof result == "function"
							initializers ?= []
							initializers.push(result)
				else if attrName.substring(0, 2) == "on"
					feature = buildEvent(scope, dom, attrName.substring(2), attrValue)
					features ?= []
					features.push(feature)
				else
					feature = buildAttrFeature(dom, attrName, attrValue)
					features ?= []
					features.push(feature)

	for customDomCompiler in dorado._userDomCompiler.$
		result = customDomCompiler(scope, dom, context)
		if result
			if result instanceof dorado._BindingFeature
				features.push(result)
			if typeof result == "function"
				initializers ?= []
				initializers.push(result)

	if removeAttrs
		for removeAttr in removeAttrs
			dom.removeAttribute(removeAttr)

	if features?.length
		if bindingType == "repeat"
			domBinding = new dorado._RepeatDomBinding(dom, scope, features)
			scope = domBinding.scope
			defaultPath = scope.data.alias
		else if bindingType == "alias"
			domBinding = new dorado._AliasDomBinding(dom, scope, features)
			scope = domBinding.scope
			defaultPath = scope.data.alias
		else
			domBinding = new dorado._DomBinding(dom, scope, features)

	childContext = {}
	for k, v of context
		childContext[k] = v
	childContext.inRepeatTemplate = context.inRepeatTemplate or bindingType == "repeat"
	childContext.defaultPath = defaultPath if defaultPath

	child = dom.firstChild
	while child
		child = _doRrenderDomTemplate(child, scope, childContext)
		child = child.nextSibling

	if initializers
		if context.inRepeatTemplate or domBinding instanceof dorado._RepeatDomBinding
			dorado.util.userData(dom, dorado.constants.DOM_INITIALIZER_KEY, initializers)
		else
			for initializer in initializers
				initializer(scope, dom)

	if domBinding
		domBinding.refresh(true) unless context.inRepeatTemplate
		if domBinding instanceof dorado._RepeatDomBinding
			tailDom = dorado.util.userData(domBinding.dom, dorado.constants.REPEAT_TAIL_KEY)
			dom = tailDom or domBinding.dom
	return dom

buildAliasFeature = (expression) ->
	return new dorado._AliasFeature(expression)

buildRepeatFeature = (expression) ->
	return new dorado._RepeatFeature(expression)

buildBindFeature = (expression, dom) ->
	nodeName = dom.nodeName
	if nodeName == "INPUT"
		type = dom.type
		if type == "checkbox"
			feature = new dorado._CheckboxFeature(expression)
		else if type == "radio"
			feature = new dorado._RadioFeature(expression)
		else
			feature = new dorado._TextBoxFeature(expression)
	else if nodeName == "SELECT"
		feature = new dorado._SelectFeature(expression)
	else if nodeName == "TEXTAREA"
		feature = new dorado._TextBoxFeature(expression)
	else
		feature = new dorado._DomAttrFeature(expression, "text", false)
	return feature

createContentPart = (part, scope) ->
	if part instanceof dorado.Expression
		expression = part
		textNode = document.createElement("span")
		feature = new dorado._TextNodeFeature(expression)
		domBinding = new dorado._DomBinding(textNode, scope, feature)
		domBinding.refresh()
	else
		textNode = document.createTextNode(part)
	return textNode

buildContent = (parts, dom, scope) ->
	if parts.length == 1
		childNode = createContentPart(parts[0], scope)
	else
		childNode = document.createDocumentFragment()
		for part in parts
			partNode = createContentPart(part, scope)
			childNode.appendChild(partNode)
	dorado._ignoreNodeRemoved = true
	dom.parentNode.replaceChild(childNode, dom)
	dorado._ignoreNodeRemoved = false
	return

buildStyleFeature = (styleStr) ->
	return false unless styleStr
	style = dorado.util.parseStyleLikeString(styleStr)

	features = []
	for styleProp, styleExpr of style
		expression = dorado._compileExpression(styleExpr)
		if expression
			feature = new dorado._DomAttrFeature(expression, styleProp, true)
			features.push(feature)
	return features

buildClassFeature = (classStr) ->
	return false unless classStr
	classConfig = dorado.util.parseStyleLikeString(classStr)

	features = []
	for className, classExpr of classConfig
		expression = dorado._compileExpression(classExpr)
		if expression
			feature = new dorado._DomClassFeature(expression, className, true)
			features.push(feature)
	return features

buildAttrFeature = (dom, attr, expr) ->
	expression = dorado._compileExpression(expr)
	if expression
		if attr == "display"
			feature = new dorado._DisplayFeature(expression)
		else if attr == "options" and dom.nodeName == "SELECT"
			feature = new dorado._SelectOptionsFeature(expression)
		else
			feature = new dorado._DomAttrFeature(expression, attr, false)
	return feature

buildEvent = (scope, dom, event, expr) ->
	expression = dorado._compileExpression(expr)
	if expression
		feature = new dorado._EventFeature(expression, event)
	return feature