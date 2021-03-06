class dorado.Dialog extends dorado.Layer
	@CLASS_NAME: "dialog transition v-box hidden"
	@ATTRIBUTES:
		context: null
		header:
			setter: (value)->
				@_setInternal(value, "header")
				return @

		content:
			setter: (value)->
				@_setInternal(value, "content")
				return @

		actions:
			setter: (value)->
				@_setInternal(value, "actions")
				return @

		modal:
			defaultValue: true
		closeable:
			defaultValue: true
		modalOpacity:
			defaultValue: 0.6
		dimmerClose:
			defaultValue: false

	getContentContainer: ()->
		return null unless @_dom
		unless @_doms.content
			@_makeInternalDom("content")

		return @_doms.content

	_setDom: (dom, parseChild)->
		super(dom, parseChild)

		@_doms ?= {}
		unless @_doms.content then @_makeInternalDom("content")

		for container in ["header", "actions"]
			key = "_#{container}"
			if @[key]?.length
				@_makeInternalDom(container) unless @_doms[container]
				@_render(el, container) for el in @[key]

		return

	_createCloseButton: ()->
		dom = @_closeBtn = $.xCreate({
			tagName: "div"
			class: "ui icon button close-btn"
			content: [
				{
					tagName: "i"
					class: "close icon"
				}
			]
			click: ()=> @hide()
		})
		return dom

	_doRefreshDom: ()->
		return unless @_dom
		super()
		if @get("closeable")
			unless @_closeBtn then @_createCloseButton()
			@_dom.appendChild(@_closeBtn) if @_closeBtn.parentNode isnt @_dom
		else
			$(@_closeBtn).remove()

	_onShow: ()->
		height = @_dom.offsetHeight
		actionsDom = @_doms.actions
		if actionsDom
			actionsHeight = actionsDom.offsetHeight
			headerHeight = 0
			if @_doms.header then headerHeight = @_doms.header.offsetHeight
			minHeight = height - actionsHeight - headerHeight
			$(@_doms.content).css("min-height", "#{minHeight}px")
		super()
	_onHide: ()->
		super()
#		@_hideModalLayer()
	_transition: (options, callback)->
		arg = {}
		@fire("before#{options.target.substring(0, 1).toUpperCase() + options.target.substring(1)}", @, {})
		return false if arg.processDefault is false
		$dom = @get$Dom()

		if @get("modal")
			if options.target is "show" then @_showModalLayer() else @_hideModalLayer()
		if options.target is "show"
			width = $dom.width()
			height = $dom.height()
			parentNode = @_context or @_dom.parentNode
			pWidth = $(parentNode).width()
			pHeight = $(parentNode).height()
			$dom.css({
				left: (pWidth - width) / 2
				top: (pHeight - height) / 2
				zIndex: dorado.floatWidget.zIndex()
			})

		options.animation or= "scale"

		@_doTransition(options, callback)

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
		flex = if target is "content" then "flex-box" else "box"
		$fly(dom).addClass(flex)
		@_doms[target] = dom

		return dom

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

	_showModalLayer: ()->
		@_doms ?= {}
		_dimmerDom = @_doms.modalLayer

		unless _dimmerDom
			_dimmerDom = $.xCreate({
				tagName: "Div"
				class: "ui dimmer"
				contextKey: "dimmer"
			})
			if @_dimmerClose
				$(_dimmerDom).on("click",()=> @hide())
			container = @_context or @_dom.parentNode
			container.appendChild(_dimmerDom)
			@_doms.modalLayer = _dimmerDom

		$(_dimmerDom).css({
			opacity: @get("modalOpacity")
			zIndex: dorado.floatWidget.zIndex()
		}).addClass("active")

		return

	_hideModalLayer: ()->
		@_doms ?= {}
		_dimmerDom = @_doms.modalLayer
		$(_dimmerDom).removeClass("active")

