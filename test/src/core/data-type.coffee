#IMPORT_BEGIN
if exports?
	XDate = require("./../lib/xdate")
	dorado = require("./expression")
	require("./date")
	module?.exports = dorado
else
	XDate = @XDate
	dorado = @dorado
#IMPORT_END

class dorado.DataType extends dorado.Element
	@ATTRIBUTES:
		name:
			readOnlyAfterCreate: true

	constructor: (config) ->
		if config?.name
			@_name = config.name
			delete config.name
			scope = config?.scope or dorado.currentScope
			if scope and DataType.autoRegister
				scope.data.regDataType(@)
		super(config)

class dorado.BaseDataType extends dorado.DataType

class dorado.StringDataType extends dorado.BaseDataType
	toText: (value) ->
		return if value? then value + "" else ""

	parse: (text) ->
		return text

class dorado.NumberDataType extends dorado.BaseDataType
	@ATTRIBUTES:
		isInteger: null

	parse: (text) ->
		if !text then return 0

		if typeof text == "number"
			if @_isInteger
				return Math.round(text)
			else
				return text

		if @_isInteger
			n = Math.round(parseInt(text, 10))
		else
			n = parseFloat(text, 10)
		return if isNaN(n) then 0 else n

class dorado.BooleanDataType extends dorado.BaseDataType
	parse: (text) ->
		if !text then return false
		if typeof text == "boolean" then return text
		if ["true", "on", "yes", "y", "1"].indexOf((text + "").toLowerCase()) > -1 then return true
		return false

class dorado.DateDataType extends dorado.BaseDataType
	parse: (text) ->
		if !text then return new Date(NaN)
		xDate = new XDate(text)
		return xDate.toDate()

class dorado.JSONDataType extends dorado.DataType
	toText: (value) ->
		return JSON.stringify(value)

	parse: (text) ->
		return JSON.parse(text)

###
EntityDataType
###

class dorado.EntityDataType extends dorado.DataType
	@ATTRIBUTES:
		readOnly: null

		properties:
			setter: (properties) ->
				@_properties.clear()
				if properties instanceof Array
					for property in properties
						@addProperty(property)

	@EVENTS:
		beforeCurrentChange: null
		currentChange: null

		beforeDataChange: null
		dataChange: null

		beforeEntityInsert: null
		entityInsert: null

		beforeEntityDelete: null
		entityDelete: null

	constructor: (config) ->
		@_properties = new dorado.util.KeyedArray()
		super(config)

	addProperty: (property) ->
		if !(property instanceof dorado.Property)
			if typeof property.compute == "function"
				property = new dorado.ComputeProperty(property)
			else
				property = new dorado.BaseProperty(property)
		else if property._owner and property._owner != @
			throw new dorado.I18nException("dorado.error.objectNotFree", "Property(#{property._name})", "DataType")

		if @_properties.get(property._name)
			@removeProperty(property._name)

		@_properties.add(property._name, property)
		property._owner = @
		return property

	removeProperty: (property) ->
		if property instanceof dorado.Property
			@_properties.remove(property._name)
		else
			property = @_properties.remove(property)
		delete property._owner
		return property

	getProperty: (name) ->
		i = name.indexOf(".")
		if i > 0
			part1 = name.substring(0, i)
			part2 = name.substring(i + 1)
			prop = @_getProperty(part1)
			if prop?._dataType
				return prop?._dataType.getProperty(part2)
		else
			return @_getProperty(name)

	_getProperty: (name) ->
		return @_properties.get(name)

	getProperties: () ->
		return @_properties

class dorado.Property extends dorado.Element
	@ATTRIBUTES:
		name:
			readOnlyAfterCreate: true
		owner:
			readOnly: true
		caption: null
		dataType:
			setter: dorado.DataType.dataTypeSetter
		description: null

	constructor: (config) ->
		super(config)

class dorado.BaseProperty extends dorado.Property
	@ATTRIBUTES:
		provider:
			setter: (provider) ->
				if provider? and !(provider instanceof dorado.Provider)
					provider = new dorado.Provider(provider)
				@_provider = provider
				return
		defaultValue: null
		readOnly: null
		required: null
		aggregated:
			readOnlyAfterCreate: true
		validators:
			setter: (validators) ->
				return
			getter: () ->
				return null

	@EVENTS:
		beforeWrite: null
		write: null
		beforeLoad: null
		loaded: null

class dorado.ComputeProperty extends dorado.Property
	@ATTRIBUTES:
		delay: null
		watchingDataPath: null

	@EVENTS:
		compute:
			singleListener: true

	compute: (entity) ->
		return @fire("compute", @, {entity: entity})

dorado.DataType.dataTypeSetter = (dataType) ->
	if typeof dataType == "string"
		name = dataType
		scope = dorado.currentScope
		if scope
			dataType = scope.dataType(name)
		else
			dataType = dorado.DataType.defaultDataTypes[name]
		if !dataType
			throw new dorado.I18nException("dorado.error.unrecognizedDataType", name)
	else if dataType? and not (dataType instanceof dorado.DataType)
		dataType = new dorado.EntityDataType(dataType)
	@_dataType = dataType or null
	return

dorado.DataType.jsonToEntity = (json, dataType, aggregated) ->
	if aggregated == undefined
		if json instanceof Array
			aggregated = true
		else if typeof json == "object" and json.hasOwnProperty("$data")
			aggregated = json.$data instanceof Array
		else
			aggregated = false

	if aggregated
		return new dorado.EntityList(dataType, json)
	else
		if json instanceof Array
			throw new dorado.I18nException("dorado.error.unmatchedDataType", "Object", "Array")
		return new dorado.Entity(dataType, json)

dorado.DataType.jsonToData = (json, dataType, aggregated) ->
	if dataType instanceof dorado.StringDataType and typeof json != "string" or dataType instanceof dorado.BooleanDataType and typeof json != "boolean" or dataType instanceof dorado.NumberDataType and typeof json != "number" or dataType instanceof dorado.DateDataType and !(json instanceof Date)
		result = dataType.parse(json)
	else if dataType instanceof dorado.EntityDataType
		result = dorado.DataType.jsonToEntity(json, dataType, aggregated)
	else if dataType and typeof json == "object"
		result = dataType.parse(json)
	else
		result = json
	return result

dorado.DataType.defaultDataTypes = defaultDataTypes =
	"string": new dorado.StringDataType(name: "string")
	"int": new dorado.NumberDataType(name: "int", isInteger: true)
	"float": new dorado.NumberDataType(name: "float")
	"boolean": new dorado.BooleanDataType(name: "boolean")
	"date": new dorado.DateDataType(name: "date")
	"json": new dorado.JSONDataType(name: "json")
	"entity": new dorado.EntityDataType(name: "entity")

defaultDataTypes["number"] = defaultDataTypes["int"]

dorado.DataType.autoRegister = true