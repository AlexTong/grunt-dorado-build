class dorado.Modal extends dorado.Widget
	@CLASS_NAME: "modal"
	@ATTRIBUTES:
		context: null
		header:
			setter: (value)->
				@_serInternal(value, "header")
				return @

		content:
			setter: (value)->
				@_serInternal(value, "content")
				return @

		actions:
			setter: (value)->
				@_serInternal(value, "actions")
				return @

	@EVENTS:
		onShow: null
		onVisible: null
		onHide: null
		onHidden: null
		onApprove: null
		onDeny: null

	_setDom: (dom, parseChild)->
		super(dom, parseChild)
		@_doms ?= {}
		for className in ["header", "content", "actions"]
			key = "_#{className}"
			if @[key]?.length
				@_makeInternalDom(className) unless @_doms[className]
				@_render(el, className) for el in @[key]
		fireEvent = (eventName)=>
			arg =
				event: window.event
			@fire(eventName, @, arg)
		settings = {
			closable: false
			onShow: ()->
				fireEvent("onShow")

			onVisible: ()->
				fireEvent("onVisible")

			onHide: ()->
				fireEvent("onHide")

			onHidden: ()->
				fireEvent("onHidden")

			onApprove: ()->
				fireEvent("onApprove")
				return false

			onDeny: ()->
				fireEvent("onDeny")
				return false
		}

		settings.context = $(@_context) if @_context

		@get$Dom().modal(settings)

		return

	_parseElement: (element)->
		result = null
		if typeof element == "string"
			result = $.xCreate({
				tagName: "SPAN"
				content: element
			})
		else if element.constructor == Object.prototype.constructor and element.$type
			widget = dorado.widget(element)
			result = widget
		else if element instanceof dorado.Widget
			result = element
		else
			result = $.xCreate(element)

		return result

	_clearInternal: (target)->
		old = @["_#{target}"]
		if old
			for el in old
				el.destroy() if el instanceof dorado.widget
			@["_#{target}"] = []

		@_doms ?= {}
		$(@_doms[target]).empty()if @_doms[target]
		return

	_serInternal: (value, target)->
		@_clearInternal(target)

		if value instanceof Array
			for el in value
				result = @_parseElement(el)
				@_addInternalElement(result, target) if result
		else
			result = @_parseElement(el)
			@_addInternalElement(result, target)  if result

		return

	_makeInternalDom: (target)->
		@_doms ?= {}
		dom = document.createElement("div")
		dom.className = target

		if target is "content"
			if @_doms["actions"]
				$(@_doms["actions"]).before(dom)
			else
				@_dom.appendChild(dom)
		else if target is "header"
			afterEl = @_doms["content"] || @_doms["actions"]
			if afterEl
				$(afterEl).before(dom)
			else
				@_dom.appendChild(dom)
		else
			@_dom.appendChild(dom)

		@_doms[target] = dom

		return dom

	_addInternalElement: (element, target)->
		name = "_#{target}"
		@[name] ?= []
		targetList = @[name]

		dom = null
		if element instanceof dorado.Widget
			targetList.push(element)
			dom = element.getDom() if @_dom
		else if element.nodeType == 1
			targetList.push(element)
			dom = element

		@_render(dom, target) if dom and @_dom
		return

	_render: (node, target)->
		@_doms ?= {}

		@_makeInternalDom(target) unless @_doms[target]
		dom = node

		if node instanceof dorado.Widget
			dom = node.getDom()

		@_doms[target].appendChild(dom) if dom.parentNode isnt @_doms[target]
		return

	_parseDom: (dom)->
		@_doms ?= {}

		_parseChild = (node, target)=>
			childNode = node.firstChild
			while childNode
				if childNode.nodeType == 1
					widget = dorado.widget(childNode)
					@_addInternalElement(widget or childNode, target)
				childNode = childNode.nextSibling

			return

		child = dom.firstChild
		while child
			if child.nodeType == 1
				if child.nodeName is "I"
					@_doms.icon = child
					@_icon ?= child.className
				else
					$child = $(child)
					for className in ["header", "content", "actions"]
						continue unless $child.hasClass(className)
						@_doms[className] = child
						_parseChild(child, className)
						break
			child = child.nextSibling

		return

	show: ()->
		@get$Dom().modal("show")
		return @

	hide: ()->
		@get$Dom().modal("hide")
		return @

	setContext: (selector)->
		@get$Dom().modal("setting context", $(selector))
		return @


