#IMPORT_BEGIN
if exports?
	dorado = require("./util")
	module?.exports = dorado
else
	dorado = this.dorado
#IMPORT_END

dorado.version = "${version}"

uniqueIdSeed = 1

dorado.uniqueId = () ->
	return "_id" + (uniqueIdSeed++)

dorado.sequenceNo = () ->
	return uniqueIdSeed++

if window?
	(() ->
		dorado.browser = {}
		dorado.os = {}

		ua = window.navigator.userAgent.toLowerCase()

		if (s = ua.match(/webkit\/([\d.]+)/))
			dorado.browser.webkit = s[1] or -1
			if (s = ua.match(/chrome\/([\d.]+)/)) then dorado.browser.chrome = parseFloat(s[1]) or -1
			else if (s = ua.match(/version\/([\d.]+).*safari/)) then dorado.browser.safari = parseFloat(s[1]) or -1
		else if (s = ua.match(/msie ([\d.]+)/)) then dorado.browser.ie = parseFloat(s[1]) or -1
		else if (s = ua.match(/trident/)) then dorado.browser.ie = 11
		else if (s = ua.match(/firefox\/([\d.]+)/)) then dorado.browser.mozilla = parseFloat(s[1]) or -1
		else if (s = ua.match(/opera.([\d.]+)/)) then dorado.browser.opera = parseFloat(s[1]) or -1
		else if (s = ua.match(/qqbrowser\/([\d.]+)/)) then dorado.browser.qqbrowser = parseFloat(s[1]) or -1

		if (s = ua.match(/(android)\s+([\d.]+)/))
			dorado.os.android = parseFloat(s[1]) or -1
			if(s = ua.match(/micromessenger\/([\d.]+)/)) then dorado.browser.weixin = parseFloat(s[1]) or -1
		else if (s = ua.match(/(iphone|ipad).*os\s([\d_]+)/)) then dorado.os.ios = parseFloat(s[2]) or -1
		else if (s = ua.match(/(windows)[\D]*([\d]+)/)) then dorado.os.windows = parseFloat(s[1]) or -1

		dorado.os.mobile = `!!("ontouchstart" in window)` and ua.match(/(mobile)/)
		dorado.os.desktop = !dorado.os.mobile
		return
	)()

###
Event
###

doradoEventRegistry =
	settingChange: {}
	exception: {}

dorado.on = (eventName, listener) ->
	i = eventName.indexOf(":")
	if i > 0
		alias = eventName.substring(i + 1)
		eventName = eventName.substring(0, i)

	listenerRegistry = doradoEventRegistry[eventName]
	if !listenerRegistry
		throw new dorado.I18nException("dorado.error.unrecognizedEvent", eventName)

	if typeof listener != "function"
		throw new dorado.I18nException("dorado.error.invalidListener", eventName)

	listeners = listenerRegistry.listeners
	aliasMap = listenerRegistry.aliasMap
	if listeners
		if alias and aliasMap?[alias] > -1 then dorado.off(eventName + ":" + alias)
		listeners.push(listener)
		i = listeners.length - 1
	else
		listenerRegistry.listeners = listeners = [listener]
		i = 0

	if alias
		if !aliasMap
			listenerRegistry.aliasMap = aliasMap = {}
		aliasMap[alias] = i
	return @

dorado.off = (eventName, listener) ->
	i = eventName.indexOf(":")
	if i > 0
		alias = eventName.substring(i + 1)
		eventName = eventName.substring(0, i)

	listenerRegistry = doradoEventRegistry[eventName]
	if !listenerRegistry then return @

	listeners = listenerRegistry.listeners
	if !listeners or listeners.length == 0 then return @

	i = -1
	if alias
		aliasMap = listenerRegistry.aliasMap
		i = aliasMap?[alias]

		if i > -1
			delete aliasMap?[alias]
			listeners.splice(i, 1)
	else if listener
		i = listeners.indexOf(listener)
		if i > -1
			listeners.splice(i, 1)

			aliasMap = listenerRegistry.aliasMap
			if aliasMap
				for alias of aliasMap
					if aliasMap[alias] == listener
						delete aliasMap[alias]
						break
	else
		delete listenerRegistry.listeners
		delete listenerRegistry.aliasMap

	return @

dorado.getListeners = (eventName) ->
	listener = doradoEventRegistry[eventName]?.listeners
	return if listener?.length then listener else null

dorado.fire = (eventName, self, arg = {}) ->
	listeners = doradoEventRegistry[eventName]?.listeners
	if listeners
		for listener in listeners
			retValue = listener.call(@, self, arg)
			if retValue == false
				return false
	return true

###
Setting
###

setting = {
	defaultCharset: "utf-8"
}

dorado.setting = (key, value) ->
	if typeof key == "string"
		if value != undefined
			# setting(string, any)
			setting[key] = value
			if dorado.getListeners("settingChange")
				dorado.fire("settingChange", dorado, {key: key})
		else
			# setting(string)
			return setting[key]
	else if typeof key == "object"
		# setting(object)
		for k, v of key
			setting[k] = v
			if dorado.getListeners("settingChange")
				dorado.fire("settingChange", dorado, {key: k})
	return @

definedSetting = doradoSetting? or global?.doradoSetting
if definedSetting
	for key, value of definedSetting then dorado.setting(key, value)

###
Exception
###

exceptionStack = []

alertException = (ex) ->
	if ex instanceof dorado.Exception or ex instanceof Error
		msg = ex.message
	else
		msg = ex + ""
	alert?(msg)
	return

class dorado.Exception
	constructor: (@message, @error)->
		if @error then console?.trace?(@error)

		exceptionStack.push(@)
		run = ()->
			if exceptionStack.indexOf(@) > -1
				dorado.Exception.processException(@);
			return
		setTimeout(run.bind(@), 50);

	@processException = (ex) ->
		if dorado.Exception.ignoreAll then return

		if ex then dorado.Exception.removeException(ex)
		if ex instanceof dorado.AbortException then return

		if !dorado.fire("exception", dorado, {exception: ex}) then return

		if ex instanceof dorado.RunnableException
			eval("var fn = function(){#{ex.script}}")
			scope = if window? then window else @
			fn.call(scope)
		else
			if dorado.Exception.ignoreAll then return
			try
				if document?.body
					if ex.showException
						ex.showException()
					else
						dorado.Exception.showException(ex)
				else
					if ex.safeShowException
						ex.safeShowException()
					else
						dorado.Exception.safeShowException(ex)
			catch ex2
				dorado.Exception.removeException(ex2)
				if ex2.safeShowException
					ex2.safeShowException()
				else
					dorado.Exception.safeShowException(ex2)
		return

	@removeException = (ex) ->
		i = exceptionStack.indexOf(ex)
		if i > -1 then exceptionStack.splice(i, 1)
		return

	@safeShowException: (exception) ->
		alertException(exception)
		return

	@showException: (exception) ->
		alertException(exception)
		return

class dorado.AbortException extends dorado.Exception
	constructor: () ->

class dorado.RunnableException extends dorado.Exception
	constructor: (@script) ->
		super("[script]")

###
I18N
###

defaultLocale = "zh"

i18nStore = {}

sprintf = (templ, params...) ->
	for param, i in params
		templ = templ.replace(new RegExp("\\{#{i}\\}", "g"), param)
	return templ

dorado.i18n = (key, params...) ->
	if typeof key == "string"
		# i18n(key, params...)
		# read i18n resource
		locale = dorado.setting("locale") or defaultLocale
		templ = i18nStore[locale]?[key]
		if templ
			if params.length
				return sprintf.apply(@, [templ].concat(params))
			else
				return templ
		else
			return key
	else
		# i18n(bundle, locale)
		# load i18n resources from bundle(json)
		bundle = key
		locale = params[0] or defaultLocale
		oldBundle = i18nStore[locale]
		if oldBundle
			for key, str of bundle
				oldBundle[key] = str
		else
			i18nStore[locale] = oldBundle = bundle
		return

class dorado.I18nException extends dorado.Exception
	constructor: (key, params...) ->
		super(dorado.i18n(key, params...))

###
Mothods
###

dorado.callback = (callback, success, result) ->
	return unless callback
	if typeof callback == "function"
		if success
			return callback.call(@, result)
	else
		scope = callback.scope or @
		if callback.delay
			run = () ->
				callback.callback.call(scope, success, result)
				return
			setTimeout(run, callback.delay)
			return
		else
			return callback.callback.call(scope, success, result)
