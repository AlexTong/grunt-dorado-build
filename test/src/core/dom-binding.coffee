_destroyDomBinding = (node, data) ->
	domBinding = data[dorado.constants.DOM_BINDING_KEY]
	domBinding?.destroy()
	return

class dorado._DomBinding
	constructor: (dom, @scope, feature) ->
		@dom = dom
		@$dom = $(dom)
		dorado.util.userData(dom, dorado.constants.DOM_BINDING_KEY, @)
		dorado.util.onNodeRemoved(dom, _destroyDomBinding)

		if feature
			if feature instanceof Array
				for f in feature
					@addFeature(f)
			else
				@addFeature(feature)

	destroy: () ->
		_feature = @feature
		if _feature
			if _feature instanceof Array
				for feature in _feature
					@unbindFeature(feature)
			else
				@unbindFeature(_feature)
		delete @dom
		delete @$dom
		return

	bindFeature: (feature) ->
		return unless feature._processMessage

		path = feature.path
		if path
			if typeof path == "string"
				@bind(path, feature)
			else
				for p in path
					@bind(p, feature)
		return

	unbindFeature: (feature) ->
		return unless feature._processMessage

		path = feature.path
		if path
			if typeof path == "string"
				@unbind(path, feature)
			else
				for p in path
					@unbind(p, feature)
		return

	addFeature: (feature) ->
		feature.id ?= dorado.uniqueId()
		feature.init?(@)

		if !@feature
			@feature = feature
		else if @feature instanceof Array
			@feature.push(feature)
		else
			@feature = [@feature, feature]

		@bindFeature(feature)
		return

	removeFeature: (feature) ->
		_feature = @feature
		if _feature
			if _feature == feature
				delete @feature
				if _feature.length == 1
					delete @feature
			else
				i = _feature.indexOf(feature)
				_feature.splice(i, 1) if i > -1
			@unbindFeature(feature)
		return

	bind: (path, feature) ->
		pipe = {
			_processMessage: (bindingPath, path, type, arg) =>
				feature._processMessage(@, bindingPath, path, type, arg)
		}
		@scope.data.bind(path, pipe)
		@[feature.id] = pipe
		return

	unbind: (path, feature) ->
		pipe = @[feature.id]
		delete @[feature.id]
		@scope.data.unbind(path, pipe)
		return

	refresh: (force) ->
		feature = @feature
		if feature instanceof Array
			f.refresh(@, force) for f in feature
		else if feature
			feature.refresh(@, force) 
		return

	clone: (dom, scope) ->
		return new @constructor(dom, scope, @feature, true)

class dorado._AliasDomBinding extends dorado._DomBinding
	destroy: () ->
		super()
		@scope.destroy() if @subScopeCreated
		return

class dorado._RepeatDomBinding extends dorado._DomBinding
	constructor: (dom, scope, feature, clone) ->
		if clone
			super(dom, scope, feature)
		else
			@scope = scope
			headerNode = document.createComment("Repeat Head ")
			dorado._ignoreNodeRemoved = true
			dom.parentNode.replaceChild(headerNode, dom)
			dorado.util.cacheDom(dom)
			dorado._ignoreNodeRemoved = false
			@dom = headerNode

			dorado.util.userData(headerNode, dorado.constants.DOM_BINDING_KEY, @)
			dorado.util.userData(headerNode, dorado.constants.REPEAT_TEMPLATE_KEY, dom)
			dorado.util.onNodeRemoved(headerNode, _destroyDomBinding)

			repeatItemDomBinding = new dorado._RepeatItemDomBinding(dom, null)
			repeatItemDomBinding.repeatDomBinding = @
			repeatItemDomBinding.isTemplate = true

			if feature
				if feature instanceof Array
					for f in feature
						if f instanceof dorado._RepeatFeature
							@addFeature(f)
						else
							repeatItemDomBinding.addFeature(f)
				else
					if feature instanceof dorado._RepeatFeature
						@addFeature(feature)
					else
						repeatItemDomBinding.addFeature(feature)

	destroy: () ->
		super()
		@scope.destroy() if @subScopeCreated
		delete @currentItemDom
		return

class dorado._RepeatItemDomBinding extends dorado._AliasDomBinding
	destroy: () ->
		super()
		if !@isTemplate
			delete @repeatDomBinding.itemDomBindingMap?[@itemId]
		return

	clone: (dom, scope) ->
		cloned = super(dom, scope)
		cloned.repeatDomBinding = @repeatDomBinding
		return cloned

	bind: (path, feature) ->
		return if @isTemplate
		return super(path, feature)

	bindFeature: (feature) ->
		return if @isTemplate
		return super(feature)

	processDataMessage: (path, type, arg) ->
		if !@isTemplate
			@scope.data._processMessage("**", path, type, arg)
		return

	refresh: () ->
		return if @isTemplate
		return super()

	remove: () ->
		if !@isTemplate
			@$dom.remove()
		return