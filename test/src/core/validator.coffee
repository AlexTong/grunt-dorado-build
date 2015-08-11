#IMPORT_BEGIN
if exports?
	dorado = require("./element")
	module?.exports = dorado
else
	dorado = @dorado
#IMPORT_END

dorado.registerTypeResolver "validator", (config) ->
	return unless config and config.$type
	return dorado[$.camelCase(config.$type) + "Validator"]

dorado.registerTypeResolver "validator", (config) ->
	if typeof config == "function"
		return dorado.CustomValidator
	else if config?.action
		return dorado.ActionValidator

class dorado.Validator extends dorado.Element
	@ATTRIBUTES:
		disabled: null

	validate: () ->
		return if @_disabled
		return @_validate.apply(@, arguments)

class dorado.CustomValidator extends dorado.Element
	@ATTRIBUTES:
		func: null

	constructor: (config) ->
		if typeof config == "function"
			@set("func", config)
		else
			super(config)

	_validate: () ->
		return @_func?.apply(@, arguments)

class dorado.RequireValidator extends dorado.Validator
	@ATTRIBUTES:
		trim:
			defaultValue: true

	_validate: (data) ->
		return

class dorado.NumberValidator extends dorado.Validator
	@ATTRIBUTES:
		min: null
		minInclude:
			defaultValue: true
		max: null
		maxInclude:
			defaultValue: true

	_validate: (data) ->
		return

class dorado.LengthValidator extends dorado.Validator
	@ATTRIBUTES:
		min: null
		max: null

	_validate: (data) ->
		return

class dorado.RegExpValidator extends dorado.Validator
	@ATTRIBUTES:
		regExp: null
		mode:
			defaultValue: "white"
			enum: ["white", "black"]

	_validate: (data) ->
		return

class dorado.EmailValidator extends dorado.Validator
	_validate: (data) ->
		return

class dorado.AsyncValidator extends dorado.Validator
	@ATTRIBUTES:
		defaultValue: true

class dorado.ActionValidator extends dorado.AsyncValidator
	@ATTRIBUTES:
		action: null
		async:
			getter: () ->
				return @_action?.get("async")

	_validate: (data, callback) ->
		if @_action
			action = @_action
			parameter = action.get("parameter")
			if parameter
				if dorado.util.isSimpleValue(parameter)
					oldParameter = parameter
					parameter = {
						data: data
						parameter: oldParameter
					}
				else
					parameter.data = data
			else
				parameter = {
					data: parameter
				}

			action.set("parameter", parameter).execute({
				scope: @
				callback: (success, result) ->
					dorado.callback(callback, success, result)
					return
			})
		else
			dorado.callback(callback, true, null)
		return