#IMPORT_BEGIN
if exports?
	dorado = require("./entity")
	module?.exports = dorado
else
	dorado = @dorado
#IMPORT_END

dorado.registerTypeResolver "action", (config) ->
	return unless config and config.$type
	return dorado[dorado.util.capitalize(config.$type) + "Action"]

dorado.registerTypeResolver "action", (config) ->
	if config?.url then return dorado.AjaxAction
	return dorado.Action

class dorado.Action extends dorado.Element
	@ATTRIBUTES:
		name:
			readOnly: true
		parameter: null
		result: null
		confirmMesssage: null
		successMesssage: null

	@EVENTS:
		beforeExecute: null
		afterExecute: null
		success: null
		failure: null

	@confirmExecuting: (scope, message, callback) ->
		callback.call(scope) if prompt(message)
		return

	@showSuccessMessage: (scope, message, callback) ->
		alert(message)
		callback?.call(scope)
		return

	_internalExecute: () ->
		try
			result = @_execute.apply(@)

			@set("result", result)
			@fire("success", @, { result: result })

			if @_successMesssage
				dorado.Action.showSuccessMessage(@, @_successMesssage)
		catch ex
			if @fire("failure", @, { exception: ex }) == false
				dorado.Exception.removeException(ex)

		@fire("afterExecute", @)
		return result

	execute: () ->
		if @_confirmMesssage
			dorado.Action.confirmExecuting(@, @_confirmMesssage, () ->
				if @fire("beforeExecute", @) == false then return
				@_internalExecute.apply(@)
				return
			)
		else
			if @fire("beforeExecute", @) == false then return
			@_internalExecute.apply(@)
		return

class dorado.AsyncAction extends dorado.Action

	@ATTRIBUTES:
		async:
			defaultValue: true
		timeout: null
		executingMesssage: null

	@showExecutingMessage: (scope, message) ->
		return 1

	@hideExecutingMessage: (scope, messageId) ->
		return

	_internalExecute: (callback) ->
		if @async or !!callback
			if @_executingMesssage
				messageId = dorado.AsyncAction.showExecutingMessage(@, @_executingMesssage)

			innerCallback = (success, result) ->
				if messageId
					dorado.AsyncAction.hideExecutingMessage(@, messageId)

				if success
					@set("result", result)
					@fire("success", @, { result: result })

					if @_successMesssage
						dorado.Action.showSuccessMessage(@, @_successMesssage)
				else
					if @fire("failure", @, { exception: result }) == false
						dorado.Exception.removeException(result)

				if callback
					dorado.callback(callback, success, result)
				@fire("afterExecute", @)

			if @getListeners("execute")
				@fire("execute", @, {
					scope: @
					callback: innerCallback
				})
			else
				@_execute(innerCallback)
			return
		else
			return super()

class dorado.AjaxAction extends dorado.AsyncAction
	@ATTRIBUTES:
		url: null
		method: null

	_getData: () ->
		return @_parameter

	_execute: (callback) ->
		$.ajax(
			async: @_async
			url: @_url
			method: @_method
			data: @_getData()
			timeout: @_timeout
			success: (result) ->
				dorado.callback(callback, true, result) if callback
				return
			error: (error) ->
				dorado.callback(callback, false, error) if callback
				return
		)
		return

class dorado.UpdateAction extends dorado.AjaxAction
	@ATTRIBUTES:
		data: null
		dataFilter:
			defaultValue: "all"
			enum: ["all", "dirty", "child-dirty", "dirty-tree"]

	@FILTER:
		"dirty": (data) ->
			if data instanceof dorado.EntityList
				filtered = []
				data.each (entity) ->
					if entity.state != dorado.Entity.STATE_NONE
						filtered.push(entity)
					return
			else if data.state != dorado.Entity.STATE_NONE
				filtered = data
			return filtered

		"child-dirty": (data) ->
			return data

		"dirty-tree": (data) ->
			return data

	_getData: () ->
		if @_cacheData?.timestamp == @_timestamp
			data = @_cacheData.data
			delete @_cacheData
			return data

		data =@_data
		if data
			if !(data instanceof dorado.Entity or data instanceof dorado.EntityList)
				if typeof data == "string"
					data = @_scope.get(data)
					if data and !(data instanceof dorado.Entity or data instanceof dorado.EntityList)
						invalidSubmitData = true
				else
					invalidSubmitData = true

			if invalidSubmitData
				throw new dorado.I18nException("dorado.error.invalidSubmitData")

			filter = dorado.UpdateAction.FILTER[@_dataFilter]
			data = if filter then filter(data) else data

		data = {
			data: @_scope.get()
			parameter: @_parameter
		}
		@_cacheData = {
			data: data
			timestamp: @_timestamp
		}
		return data

	@showNoDataMessage: (message) ->
		alert(message)
		return

	execute: (callback) ->
		@_timestamp = dorado.sequenceNo()
		data = @_getData()
		if !data?
			dorado.UpdateAction.showNoDataMessage(dorado.i18n("dorado.warn.noDataToSubmit"))
			return
		else
			return super(callback)