###
    按钮的抽象类
###
class dorado.AbstractButton extends dorado.Widget
	@ATTRIBUTES:
		size:
			enum: ["mini", "tiny", "small", "medium", "large", "big", "huge", "massive"]
			refreshDom: true
			setter: (value)->
				oldValue = @["_size"]
				@get$Dom().removeClass(oldValue) if oldValue and oldValue isnt value and @_dom
				@["_size"] = value
				return

		color:
			refreshDom: true
			enum: ["red", "orange", "yellow", "olive", "green", "teal", "blue", "violet", "purple", "pink", "brown",
				   "grey", "black"]
			setter: (value)->
				oldValue = @["_color"]
				@get$Dom().removeClass(oldValue) if oldValue and oldValue isnt value and @_dom
				@["_color"] = value
				return

		attached:
			refreshDom: true
			defaultValue: ""
			enum: ["left", "right", "top", "bottom", ""]
			setter: (value)->
				oldValue = @["_attached"]
				dorado.util.removeClass(@_dom, "#{oldValue} attached",
					true) if oldValue and oldValue isnt value and @_dom
				@["_attached"] = value
				return

	_doRefreshDom: ()->
		return unless @_dom
		super()
		size = @get("size")
		@_classNamePool.add(size) if size

		color = @get("color")
		@_classNamePool.add(color) if color

		attached = @get("attached")
		@_classNamePool.add("#{attached} attached") if attached

		return

class dorado.Button extends dorado.AbstractButton
	@SEMANTIC_CLASS: [
		"left floated", "right floated",
		"left labeled", "right labeled",
		"top attached", "bottom attached", "left attached", "right attached"
	]
	@CLASS_NAME: "button"
	@ATTRIBUTES:
		caption:
			refreshDom: true

		icon:
			refreshDom: true
			setter: (value)->
				oldValue = @["_icon"]
				@["_icon"] = value
				if oldValue and oldValue isnt value and @_dom and @_doms?.iconDom
					$iconDom = $(@_doms.iconDom)
					$iconDom.removeClass(oldValue)
				return

		iconPosition:
			refreshDom: true
			defaultValue: "left"
			enum: ["left", "right"]

		focusable:
			refreshDom: true
			defaultValue: false

		states:
			refreshDom: true
			defaultValue: ""
			enum: ["disabled", "loading", "active", ""]
			setter: (value)->
				oldValue = @["_states"]
				if oldValue and oldValue isnt value and @_dom then $fly(@_dom).removeClass(oldValue)
				@["_states"] = value
				return



	_parseDom: (dom)->
		unless @_caption
			child = dom.firstChild
			while child
				if child.nodeType == 3
					text = child.textContent
					if text
						@_caption = text
						child.textContent = ""
						break
				child = child.nextSibling

		return

	_refreshIcon: ()->
		return unless @_dom
		$dom = @get$Dom()
		@_classNamePool.remove("right labeled")
		@_classNamePool.remove("left labeled")
		@_classNamePool.remove("labeled")
		@_classNamePool.remove("icon")

		icon = @get("icon")
		iconPosition = @get("iconPosition")
		caption = @get("caption")

		if icon
			if caption
				if iconPosition is "right"
					@_classNamePool.add("right labeled")
				else
					@_classNamePool.add("labeled")
			@_classNamePool.add("icon")
			@_doms.iconDom or= document.createElement("i")
			iconDom = @_doms.iconDom
			$(iconDom).addClass("#{icon} icon")

			$dom.append(iconDom) if iconDom.parentNode isnt @_dom
		else
			$(@_doms.iconDom).remove() if @_doms.iconDom

		return

	_doRefreshDom: ()->
		return unless @_dom

		super()

		$dom = @get$Dom()
		classNamePool = @_classNamePool
		@_doms ?= {}
		caption = @get("caption")
		captionDom = @_doms.captionDom

		if caption
			unless captionDom
				captionDom = document.createElement("span")
				@_doms.captionDom = captionDom
			$(captionDom).text(caption)
			$dom.append(captionDom) if captionDom.parentNode isnt @_dom
		else
			$(captionDom).remove() if captionDom

		if @get("focusable") then $dom.attr("tabindex", "0") else  $dom.removeAttr("tabindex")

		@_refreshIcon()
		states = @_states
		if states then classNamePool.add(states)

		return

	destroy: ()->
		unless @_destroyed
			delete @_doms
			super()
		return

dorado.buttonGroup = {}

class dorado.buttonGroup.Separator extends dorado.Widget
	@SEMANTIC_CLASS:[]
	@CLASS_NAME: "or"
	@ATTRIBUTES:
		text:
			defaultValue: ""
			setter: (value)->
				@["_value"] = value
				@refresh()

	_parseDom: (dom)->
		return unless dom

		# text
		unless @_text
			text = @_dom.getAttribute("data-text")
			@_text = text if text

		return

	_doRefreshDom: ()->
		return unless @_dom
		super()

		$(@_dom).attr("data-text", @get("text")) if @_dom
		return @


dorado.buttonGroup.emptyItems = []
class dorado.ButtonGroup extends dorado.AbstractButton
	@CHILDREN_TYPE_NAMESPACE: "button-group"
	@CLASS_NAME: "buttons"
	@ATTRIBUTES:
		fluid:
			refreshDom: true
			attrName: "d-fluid"
			defaultValue: false

		mutuallyExclusive:
			refreshDom: true
			defaultValue: true

		items:
			setter: (value)->
				@clear()
				if value instanceof Array
					@addItem(item) for item in value
				return

	_setDom: (dom, parseChild)->
		@_doms ?= {}
		super(dom, parseChild)

		if @_items?.length
			for item in @_items
				itemDom = item.getDom()
				item.appendTo(@_dom) if itemDom.parentNode isnt dom

		activeExclusive = (targetDom)=>
			return unless  @_mutuallyExclusive
			return if dorado.util.hasClass(targetDom, "disabled") or dorado.util.hasClass(targetDom,
				"loading") or dorado.util.hasClass(targetDom, "active")
			$(">.ui.button.active", @_dom).each((index, itemDom)->
				if itemDom isnt targetDom
					button = dorado.widget(itemDom)
					if button
						button.set("states","")
					else
						$(itemDom).removeClass("active disabled")
				return
			)

			targetBtn = dorado.widget(targetDom)
			if targetBtn
				targetBtn.set("states", "active")
			else
				$fly(targetDom).addClass("active")

			return

		@get$Dom().delegate(">.ui.button", "click", (event)->
			activeExclusive(this, event)
		)

	_parseDom: (dom)->
		return unless dom

		child = dom.firstChild
		while child
			if child.nodeType == 1
				widget = dorado.widget(child)
				if widget
					@addItem(widget) if widget instanceof dorado.Button or widget instanceof dorado.buttonGroup.Separator
			child = child.nextSibling

		@_doms ?= {}
		return

	_resetFluid: ()->
		return unless @_dom

		$dom = @get$Dom()
		attrName = @constructor.ATTRIBUTES.fluid.attrName
		oldFluid = $dom.attr(attrName)
		newFluid = 0
		items = @_items or []

		for item in items
			newFluid++ if item instanceof dorado.Button

		unless newFluid is oldFluid
			@_classNamePool.remove("#{oldFluid}") if oldFluid

		fluid = @get("fluid")
		if !!fluid
			@_classNamePool.add("#{newFluid}")
			@_classNamePool.add("fluid")
			$dom.attr(attrName, newFluid)

		return

	_doRefreshDom: ()->
		return unless @_dom

		super()

		@_resetFluid()
		return

	addItem: (item)->
		return @ if @_destroyed
		@_items ?= []

		itemObj = null
		if item instanceof dorado.Widget
			itemObj = item
		else if item.$type
			if item.$type is "Separator" or item.$type is "-"
				delete item["$type"]
				itemObj = new dorado.buttonGroup.Separator(item)
			else
				itemObj = dorado.widget(item)
		else if typeof item == "string"
			itemObj = new dorado.buttonGroup.Separator({text: item})

		if itemObj
			@_items.push(itemObj)

			if @_dom
				itemDom = itemObj.getDom()
				if itemDom.parentNode isnt @_dom
					@get$Dom().append(itemDom)
					dorado.util.delay(@, "refreshDom", 50, @_refreshDom)

		return @

	add: ()->
		@addItem(arg) for arg in arguments
		return @

	removeItem: (item)->
		return @ unless @_items
		index = @_items.indexOf(item)
		if index > -1
			@_items.splice(index, 1)
			item.remove()
			dorado.util.delay(@, "refreshDom", 50, @_refreshDom)
		return @

	destroy: ()->
		return if @_destroyed
		if @_items
			item.destroy() for item in @_items
			delete @_items
		super()
		return

	clear: ()->
		if @_items?.length
			item.destroy() for item in @_items
			@_items = []
			dorado.util.delay(@, "refreshDom", 50, @_refreshDom)
		return

	getItem: (index)->
		return @_items[index] if @_items

	getItems: ()->
		return @_items or dorado.buttonGroup.emptyItems

dorado.registerType("button-group", "_default", dorado.Button)
dorado.registerType("button-group", "Separator", dorado.buttonGroup.Separator)
dorado.registerTypeResolver "button-group", (config) ->
	return dorado.resolveType("widget", config)