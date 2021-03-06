#IMPORT_BEGIN
if exports?
	dorado = require("./util")
	module?.exports = dorado
else
	dorado = @dorado
#IMPORT_END

tagSplitter = " "

doMergeDefinitions = (definitions, mergeDefinitions, overwrite) ->
	return if definitions == mergeDefinitions
	for name, mergeDefinition of mergeDefinitions
		if definitions.hasOwnProperty(name)
			definition = definitions[name]
			if definition
				for prop of mergeDefinition
					if overwrite or !definition.hasOwnProperty(prop) then definition[prop] = mergeDefinition[prop]
			else
				definitions[name] = mergeDefinition
		else
			definitions[name] = mergeDefinition
	return

preprocessClass = (classType) ->
	superType = classType.__super__?.constructor
	if superType
		if classType.__super__ then preprocessClass(superType)

		# merge ATTRIBUTES
		# TODO: 此处可以考虑预先计算出有无含默认值设置的属性，以便在对象创建时提高性能
		attributes = classType.ATTRIBUTES
		if !attributes._inited
			attributes._inited = true
			doMergeDefinitions(attributes, superType.ATTRIBUTES, false)

		# merge EVENTS
		events = classType.EVENTS
		if !events._inited
			events._inited = true
			doMergeDefinitions(events, superType.EVENTS, false)
	return

class dorado.Element
	@mixin: (classType, mixin) ->
		for name, member of mixin
			if name == "ATTRIBUTES"
				mixinAttributes = member
				if mixinAttributes
					attributes = classType.ATTRIBUTES ?= {}
					doMergeDefinitions(attributes, mixinAttributes, true)
			else if name == "EVENTS"
				mixInEvents = member
				if mixInEvents
					events = classType.EVENTS ?= {}
					doMergeDefinitions(events, mixInEvents, true)
			else if name == "constructor"
				if !classType._constructors
					classType._constructors = [member]
				else
					classType._constructors.push(member)
			else if name == "destroy"
				if !classType._destructors
					classType._destructors = [member]
				else
					classType._destructors.push(member)
			else
				classType.prototype[name] = member
		return

	@ATTRIBUTES:
		tag:
			getter: ->
				return if @_tag then @_tag.join(tagSplitter) else null
			setter: (tag) ->
				dorado.tagManager.unreg(t, @) for t in @_tag if @_tag
				if tag
					@_tag = ts = tag.split(tagSplitter)
					dorado.tagManager.reg(t, @) for t in ts
				else
					@_tag = null
				return

		userData: null

	@EVENTS:
		attributeChange: null
		destroy: null

	constructor: (config) ->
		@_constructing = true
		classType = @constructor
		if !classType.ATTRIBUTES._inited or !classType.EVENTS._inited
			preprocessClass(classType)

		@_scope = config?.scope or dorado.currentScope

		attrConfigs = classType.ATTRIBUTES
		for attr, attrConfig of attrConfigs
			if attrConfig?.defaultValue != undefined
				if attrConfig.setter
					attrConfig.setter.call(@, attrConfig.defaultValue, attr)
				else
					@["_" + attr] = attrConfig.defaultValue

		if classType._constructors
			for constructor in classType._constructors
				constructor.call(@)

		if config then @set(config, true)
		delete @_constructing

	destroy: ()->
		classType = @constructor
		if classType._destructors
			for destructor in classType._destructors
				destructor.call(@)

		if @_elementAttrBindings
			for elementAttrBinding of @_elementAttrBindings
				elementAttrBinding.destroy()

		@fire("destroy", @)
		@_set("tag", null) if @_tag
		return

	get: (attr, ignoreError) ->
		if attr.indexOf(".") > -1
			paths = attr.split(".")
			obj = @
			for path in paths
				if obj instanceof dorado.Element
					obj = obj._get(path, ignoreError)
				else if typeof obj.get == "function"
					obj = obj.get(path)
				else
					obj = obj[path]
				if !obj? then break
			return obj
		else
			return @_get(attr, ignoreError)

	_get: (attr, ignoreError) ->
		if !@constructor.ATTRIBUTES.hasOwnProperty(attr)
			if ignoreError then return
			throw new dorado.I18nException("dorado.error.unrecognizedAttribute", attr)

		attrConfig = @constructor.ATTRIBUTES[attr]
		if attrConfig?.getter
			return attrConfig.getter.call(@, attr)
		else
			return @["_" + attr]

	set: (attr, value, ignoreError) ->
		if typeof attr == "string"
			# set(string, any)
			if attr.indexOf(".") > -1
				paths = attr.split(".")
				obj = @
				for path, i in paths
					if obj instanceof dorado.Element
						obj = obj._get(path, ignoreError)
					else
						obj = obj[path]
					if !obj? then break
					if i >= (paths.length - 2) then break

				if !obj? and !ignoreError
					throw new dorado.I18nException("dorado.error.invalidInstanceOfAttribute", path[0...i].join("."))

				if obj instanceof dorado.Element
					obj._set(paths[paths.length - 1], value, ignoreError)
				else if typeof obj.set == "function"
					obj.set(paths[paths.length - 1], value)
				else
					obj[paths[paths.length - 1]] = value
			else
				@_set(attr, value, ignoreError)
		else
			# set(object, ignoreError)
			config = attr
			ignoreError = value
			for attr of config
				@set(attr, config[attr], ignoreError)
		return @

	_set: (attr, value, ignoreError) ->
		if typeof value == "string" and @_scope
			if value.charCodeAt(0) == 123 # `{`
				parts = dorado._compileText(value)
				if parts.length > 0
					value = parts[0]

		if @constructor.ATTRIBUTES.hasOwnProperty(attr)
			attrConfig = @constructor.ATTRIBUTES[attr]
			if attrConfig
				if attrConfig.readOnly
					if ignoreError then return
					throw new dorado.I18nException("dorado.error.attributereadOnly", attr)

				if !@_constructing and attrConfig.readOnlyAfterCreate
					if ignoreError then return
					throw new dorado.I18nException("dorado.error.attributeReadOnlyAfterCreate", attr)
		else if value
			eventName = attr
			i = eventName.indexOf(":")
			if i > 0 then eventName = eventName.substring(0, i)
			if @constructor.EVENTS.hasOwnProperty(eventName)
				if value instanceof dorado.Expression
					expression = value
					scope = @_scope
					@on(attr, (self, arg) ->
						expression.evaluate(scope, "never", {
							vars:
								self: self
								arg: arg
						})
						return
					, ignoreError)
					return
				else if typeof value == "function"
					@on(attr, value)
					return
				else if typeof value == "string"
					action = @_scope?.action(value)
					if action
						@on(attr, action)
						return

			if ignoreError then return
			throw new dorado.I18nException("dorado.error.unrecognizedAttribute", attr)

		@_doSet(attr, attrConfig, value)

		if @_eventRegistry
			if @getListeners("attributeChange")
				@fire("attributeChange", @, {attribute: attr})
		return

	_doSet: (attr, attrConfig, value) ->
		if !@_duringBindingRefresh and @_elementAttrBindings
			elementAttrBinding = @_elementAttrBindings[attr]
			if elementAttrBinding
				elementAttrBinding.destroy()
				delete @_elementAttrBindings[attr]

		if value instanceof dorado.Expression and dorado.currentScope
			expression = value
			scope = dorado.currentScope
			elementAttrBinding = new dorado.ElementAttrBinding(@, attr, expression, scope)

			@_elementAttrBindings ?= {}
			elementAttrBindings = @_elementAttrBindings
			if elementAttrBindings
				elementAttrBindings[attr] = elementAttrBinding
			value = elementAttrBinding.evaluate()

		if attrConfig
			if attrConfig.enum and attrConfig.enum.indexOf(value) < 0
				throw new dorado.I18nException("dorado.error.attributeEnumOutOfRange", attr, value)

			if attrConfig.setter
				attrConfig.setter.call(@, value, attr )
				return

		@["_" + attr] = value
		return

	_on: (eventName, listener, alias) ->
		if alias == "once"
			alias = "__once"
			once = true

		eventConfig = @constructor.EVENTS[eventName]

		if @_eventRegistry
			listenerRegistry = @_eventRegistry[eventName]
		else
			@_eventRegistry = {}

		if !listenerRegistry
			@_eventRegistry[eventName] = listenerRegistry = {}

		if once then listenerRegistry.hasOnceListener = true
		listeners = listenerRegistry.listeners
		aliasMap = listenerRegistry.aliasMap
		if listeners
			if eventConfig?.singleListener and listeners.length
				throw new dorado.I18nException("dorado.error.singleEventListener", eventName)

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
		return

	on: (eventName, listener) ->
		i = eventName.indexOf(":")
		if i > 0
			alias = eventName.substring(i + 1)
			eventName = eventName.substring(0, i)

		if !@constructor.EVENTS.hasOwnProperty(eventName)
			throw new dorado.I18nException("dorado.error.unrecognizedEvent", eventName)

		if typeof listener != "function"
			throw new dorado.I18nException("dorado.error.invalidListener", eventName)

		@_on(eventName, listener, alias)
		return @

	_off: (eventName, listener, alias) ->
		listenerRegistry = @_eventRegistry[eventName]
		return @ unless listenerRegistry

		listeners = listenerRegistry.listeners
		return @ unless listeners and listeners.length

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
		return

	off: (eventName, listener) ->
		return @ unless @_eventRegistry

		i = eventName.indexOf(":")
		if i > 0
			alias = eventName.substring(i + 1)
			eventName = eventName.substring(0, i)

		@_off(eventName, listener, alias)
		return @

	getListeners: (eventName) ->
		return @_eventRegistry?[eventName]?.listeners

	fire: (eventName, self, arg) ->
		return true unless @_eventRegistry

		listenerRegistry = @_eventRegistry[eventName]
		if listenerRegistry
			listeners = listenerRegistry.listeners
			if listeners
				if arg
					arg.model = @._scope
				else
					arg = {model: @._scope}
				for listener in listeners
					if typeof listener == "function"
						retValue = listener.call(self, self, arg)
					else if typeof listener == "string"
						retValue = (self, arg) =>
							eval(listener)
							return

					if retValue != undefined
						result = retValue
						break

				if listenerRegistry.hasOnceListener
					delete listenerRegistry.hasOnceListener
					@off(eventName + ":__once")
		return result

###
    Element Group
###
dorado.Element.createGroup = (elements, model) ->
	if model
		elements = []
		for ele in elements
			if ele._scope && !ele._model
				scope = ele._scope
				while scope
					if scope instanceof dorado.Model
						ele._model = scope
						break
					scope = scope.parent
			if ele._model == model then elements.push(ele)
	else
		elements = if elements then elements.slice(0) else []

	elements.set = (attr, value) ->
		element.set(attr, value) for element in elements
		return @
	elements.on = (eventName, listener) ->
		element.on(eventName, listener) for element in elements
		return @
	elements.off = (eventName: string) ->
		element.off(eventName) for element in elements
		return @
	return elements

###
    Tag Manager
###

dorado.tagManager =
	registry: {}

	reg: (tag, element) ->
		elements = @registry[tag]
		if elements
			elements.push(element)
		else
			@registry[tag] = [element]
		return

	unreg: (tag, element) ->
		if element
			elements = @registry[tag]
			if elements
				i = elements.indexOf(element)
				if i > -1
					if i == 0 and elements.length == 1
						delete @registry[tag]
					else
						elements.splice(i, 1)
		else
			delete @registry[tag]
		return

	find: (tag) ->
		return @registry[tag]

dorado.tag = (tag) ->
	elements = dorado.tagManager.find(tag)
	return dorado.Element.createGroup(elements)

###
    Type Registry
###

typeRegistry = {}

dorado.registerType = (namespace, typeName, constructor) ->
	holder = typeRegistry[namespace] or typeRegistry[namespace] = {}
	holder[typeName] = constructor
	return

dorado.registerTypeResolver = (namespace, typeResolver) ->
	holder = typeRegistry[namespace] or typeRegistry[namespace] = {}
	holder._resolvers ?= []
	holder._resolvers.push(typeResolver)
	return

dorado.resolveType = (namespace, config, baseType) ->
	constructor = null
	holder = typeRegistry[namespace]
	if holder
		constructor = holder[config?.$type or "_default"]
		if !constructor and holder._resolvers
			for resolver in holder._resolvers
				constructor = resolver(config)
				if constructor
					if baseType and !dorado.util.isCompatibleType(baseType, constructor)
						throw new dorado.Exception("Incompatiable class type.")
					break
		return constructor
	return