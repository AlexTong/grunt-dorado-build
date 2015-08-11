#IMPORT_BEGIN
if exports?
	dorado = require("./keyed-array")
	module?.exports = dorado
else
	dorado = @dorado
#IMPORT_END

dorado.util.trim = (text) ->
	return if text? then String.prototype.trim.call(text) else ""

dorado.util.capitalize = (text) ->
	return text unless text
	return text.charAt(0).toUpperCase() + text.slice(1);

dorado.util.isSimpleValue = (value) ->
	if value == null or value == undefined then return false
	type = typeof value
	return type != "object" and type != "function" or type instanceof Date

dorado.util.parseStyleLikeString = (styleStr, headerProp) ->
	return false unless styleStr

	style = {}
	parts = styleStr.split(";")
	for part, i in parts
		j = part.indexOf(":")
		if j > 0
			styleProp = $.trim(part.substring(0, j))
			styleExpr = $.trim(part.substring(j + 1))
			if styleProp and styleExpr
				style[styleProp] = styleExpr
		else if i == 0 and headerProp
			style[headerProp] = $.trim(part)
		else if $.trim(part)
			invalid = true
			break

	if invalid
		throw new dorado.I18nException("dorado.error.invalidFormat", styleStr)
	return style

dorado.util.isCompatibleType = (baseType, type) ->
	if type == baseType then return true
	while type.__super__
		type = type.__super__.constructor
		if type == baseType then return true
	return false

dorado.util.delay = (owner, name, delay, fn) ->
	dorado.util.cancelDelay(owner, name)
	owner["_timer_" + name] = setTimeout(() ->
		fn.call(owner)
		return
	, delay)
	return

dorado.util.cancelDelay = (owner, name) ->
	key = "_timer_" + name
	timerId = owner[key]
	if timerId
		delete owner[key]
		clearTimeout(timerId)
	return

dorado.util.waitForAll = (funcs, callback) ->
	if !funcs or !funcs.length
		dorado.callback(callback, true)

	completed = 0
	total = funcs.length
	procedures = {}
	for func in funcs
		id = dorado.uniqueId()
		procedures[id] = true

		func({
			id: id
			callback: (success) ->
				return if disabled
				if success
					if procedures[@id]
						delete procedures[@id]
						completed++
						if completed == total
							dorado.callback(callback, true)
							disabled = true
				else
					dorado.callback(callback, false)
					disabled = true
				return
		})
	return