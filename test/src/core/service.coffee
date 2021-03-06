#IMPORT_BEGIN
if exports?
	dorado = require("./element")
	module?.exports = dorado
else
	dorado = @dorado
#IMPORT_END

class dorado.AjaxServiceInvoker
	constructor: (@ajaxService, context) ->
		@callbacks = []
		@invokerOptions = @ajaxService.getInvokerOptions(context)

	invokeCallback: (success, result) ->
		@invoking = false
		callbacks = @callbacks
		@callbacks = []
		for callback in callbacks
			dorado.callback(callback, success, result)
		return

	_invoke: (async = true) ->
		invokerOptions = @invokerOptions
		retValue = undefined

		options = {}
		for p, v of invokerOptions
			options[p] = v
		options.async = async
		options.success = (result) =>
			@invokeCallback(true, result)
			retValue = result
			return
		options.error = (error) =>
			@invokeCallback(false, error)
			return

		if options.sendJson
			options.data = JSON.stringify(options.data)

		$.ajax(options)
		return retValue

	invokeAsync: (callback) ->
		@callbacks.push(callback)
		if @invoking then return false

		@invoking = true
		@_invoke()
		return true

	invokeSync: () ->
		if @invoking
			throw new dorado.I18nException("dorado.error.getResultDuringAjax", @url)
		return @_invoke(false)

class dorado.AjaxService extends dorado.Element
	@ATTRIBUTES:
		url: null
		sendJson: null
		parameter: null
		ajaxOptions: null

	getUrl: () ->
		return @_url

	getInvokerOptions: () ->
		options = {}
		ajaxOptions = @_ajaxOptions
		if ajaxOptions
			for p, v of ajaxOptions
				options[p] = v

		options.url = @getUrl()
		options.data = @_parameter
		options.sendJson = @_sendJson
		if options.sendJson and !options.method
			options.method = ""
		return options

	getInvoker: (context) ->
		return new dorado.AjaxServiceInvoker(@, context)

class dorado.Provider extends dorado.AjaxService
	@ATTRIBUTES:
		pageSize: null
		pageNo:
			defaultValue: 1

	_evalParamValue: (expr, context) ->
		if expr.charCodeAt(0) == 58 # `:`
			if context
				return dorado.Entity._evalDataPath(context, expr.substring(1), true, "never");
			else
				return null
		else
			return expr

	getInvokerOptions: (context) ->
		options = super()
		parameter = options.data

		if parameter?
			if typeof parameter is "string"
				parameter = @_evalParamValue(parameter, context)
			else if typeof parameter is "object"
				oldParameter = parameter
				parameter = {}
				for p, v of oldParameter
					if typeof v is "string"
						v = @_evalParamValue(v, context)
					parameter[p] = v

		data = {}
		data.pageSize = @_pageSize if @_pageSize > 1
		data.pageNo = @_pageNo if @_pageNo > 1
		data.parameter = parameter if parameter?
		options.data = data
		return options

class dorado.Resolver extends dorado.AjaxService
	@ATTRIBUTES:
		method:
			defaultValue: "post"