dorado.util.addClass = (dom, value, continuous)->
	unless !!continuous
		$(dom).addClass(value)
		return dorado.util

	if dom.nodeType is 1
		className = if dom.className then (" #{dom.className} ").replace(dorado.constants.CLASS_REG, " ") else " "
		if className.indexOf(" #{value} ") < 0
			className += "#{value} "
			dom.className = $.trim(className)

	return dorado.util

dorado.util.removeClass = (dom, value, continuous)->
	unless !!continuous
		$(dom).removeClass(value)
		return dorado.util

	if dom.nodeType is 1
		className = if dom.className then (" #{dom.className} ").replace(dorado.constants.CLASS_REG, " ") else " "
		if className.indexOf(" #{value} ") >= 0
			className = className.replace(" #{value} ", " ")
			dom.className = $.trim(className)

	return dorado.util

dorado.util.toggleClass = (dom, value, stateVal, continuous)->
	unless !!continuous
		$(dom).toggleClass(value, !!stateVal)
		return

	if dom.nodeType is 1
		if !!stateVal then @_addClass(dom, value, true) else @_removeClass(dom, value, true)

	return dorado.util

dorado.util.hasClass = (dom, className)->
	names = className.split(/\s+/g)
	domClassName = if dom.className then (" #{dom.className} ").replace(dorado.constants.CLASS_REG, " ") else " "
	for name in names
		return false if domClassName.indexOf(" #{name} ") < 0
	return true

dorado.util.getTextChildData = (dom)->
	child = dom.firstChild
	while child
		return child.textContent if child.nodeType == 3
		child = child.nextSibling

	return null

dorado.util.eachNodeChild = (node, fn)->
	return dorado.util if !node or !fn

	child = node.firstChild
	while child
		break if fn(child) == false
		child = child.nextSibling

	return dorado.util


dorado.util.getScrollerRender = (element)->
	helperElem = document.createElement("div")
	perspectiveProperty = dorado.Fx.perspectiveProperty
	transformProperty = dorado.Fx.transformProperty
	if helperElem.style[perspectiveProperty] != undefined
		return (left, top, zoom)->
			element.style[transformProperty] = 'translate3d(' + (-left) + 'px,' + (-top) + 'px,0) scale(' + zoom + ')'
			return

	else if helperElem.style[transformProperty] != undefined
		return  (left, top, zoom)->
			element.style[transformProperty] = 'translate(' + (-left) + 'px,' + (-top) + 'px) scale(' + zoom + ')'
			return
	else
		return (left, top, zoom)->
			element.style.marginLeft = if left then  (-left / zoom) + 'px' else ''
			element.style.marginTop = if  top then  (-top / zoom) + 'px' else ''
			element.style.zoom = zoom || ''
			return

dorado.util.getType = do ->
	classToType = {}
	for name in "Boolean Number String Function Array Date RegExp Undefined Null".split(" ")
		classToType["[object " + name + "]"] = name.toLowerCase()

	(obj) ->
		strType = Object::toString.call(obj)
		classToType[strType] or "object"

dorado.util.typeOf = (obj, type)->
	return dorado.util.getType(obj) is type

dorado.util.getDomRect = (dom)->
	rect = dom.getBoundingClientRect()
	if isNaN(rect.height) then rect.height = rect.bottom - rect.top
	if isNaN(rect.width) then rect.width = rect.right - rect.left
	return rect