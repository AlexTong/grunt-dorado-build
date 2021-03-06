dorado.menu ?= {}

class dorado.menu.AbstractMenuItem extends dorado.Widget
	@ATTRIBUTES:
		parent: null
	onItemClick: (event, item)->
		parentMenu = @_parent
		parentMenu.onItemClick(event, item) if parentMenu and parentMenu instanceof dorado.Menu
		return
	getParent: ()-> @_parent
	hasSubMenu: ()->
		return !!this._subMenu

class dorado.menu.MenuItem extends dorado.menu.AbstractMenuItem
	@CLASS_NAME: "item"
	@TAG_NAME: "a"
	@ATTRIBUTES:
		caption: null
		icon: null
		items:
			setter: (value)->
				@_items = value
				@_resetSubMenu(value)
				return
	_parseDom: (dom)->
		child = dom.firstChild
		@_doms ?= {}
		while child
			if child.nodeType == 1
				subMenu = dorado.widget(child)
				if subMenu and subMenu instanceof dorado.Menu
					@_subMenu = subMenu
					subMenu._isSubMemu = true
				else if child.nodeName == "I"
					@_doms.iconDom = child
					@_icon ?= child.className
				else if dorado.util.hasClass(child, "caption")
					@_doms.captionDom = child

			child = child.nextSibling

		unless @_doms.captionDom
			@_doms.captionDom = $.xCreate({
				tagName: "span",
				content: @_caption or ""
			})
			dom.appendChild(@_doms.captionDom)

		return

	_setDom: (dom, parseChild)->
		super(dom, parseChild)
		$dom = $(dom)
		$dom.click((event)=>
			return @onItemClick(event, @)
		)
		$dom.append(@_subMenu.getDom())if @_subMenu and @_subMenu.parentNode isnt dom
		return

	_createDom: ()->
		icon = @get("icon") or ""
		caption = @get("caption") or ""
		return $.xCreate({
			tagName: "A",
			class: @constructor.CLASS_NAME,
			content: [
				{
					tagName: "span",
					content: caption,
					contextKey: "captionDom"
				}
			]
		}, @_doms)

	_doRefreshDom: ()->
		return unless @_dom
		super()
		@_doms ?= {}
		if !@_caption and @_icon
			@_classNamePool.add("icon")
		if @_icon
			unless @_doms.iconDom
				@_doms.iconDom = $.xCreate({
					tagName: "i",
					class: "#{@_icon or ""} icon"
				})
			if @_doms.iconDom.parentNode isnt @_dom then @get$Dom().prepend(@_doms.iconDom)
			$fly(@_doms.iconDom).addClass(@_icon)
		else
			$(@_doms.iconDom).remove()
		$(@_dom).find(">.ui.menu").removeClass("ui")
		if @_subMenu
			subMenuDom = @_subMenu.getDom()
			if subMenuDom.parentNode isnt @_dom then @_dom.appendChild(subMenuDom)

		return

	_resetSubMenu: (config)->
		@_subMenu?.destroy()
		if config
			@_subMenu = new dorado.Menu({
				items: config
			})
			@_subMenu._parent = @
			@_subMenu._isSubMemu = true
		else
			delete @_subMenu

class dorado.menu.DropdownMenuItem extends dorado.menu.MenuItem
	@CLASS_NAME: "dropdown item"

	_createDom: ()->
		caption = @get("caption") or ""

		return $.xCreate({
			tagName: "DIV",
			class: @constructor.CLASS_NAME,
			content: [
				{
					tagName: "span",
					content: caption,
					contextKey: "captionDom"
				}, {
					tagName: "i",
					class: "dropdown icon",
					contextKey: "iconDom"
				}
			]
		}, @_doms)

	_parseDom: (dom)->
		super(dom)
		iconDom = @_doms.iconDom
		$(iconDom).addClass("dropdown icon") if iconDom
		return

class dorado.menu.ControlMenuItem extends  dorado.menu.AbstractMenuItem
	@CLASS_NAME: "item"
	@ATTRIBUTES:
		control:
			setter: (value)->
				oldControl = @["_control"]
				oldControl.destroy() if oldControl
				if value.constructor == Object.prototype.constructor and value.$type
					control = dorado.widget(value)
				else if value instanceof dorado.Widget
					control = value

				@["_control"] = control
				@_dom.appendChild(control.getDom()) if control and @_dom
				return

	_parseDom: (dom)->
		child = dom.firstChild

		while child
			if child.nodeType == 1
				widget = dorado.widget(child)
				if widget
					@_control = widget
					break
			child = child.nextSibling

		return
	_doRefreshDom: ()->
		return unless @_dom
		super()

		@_classNamePool.remove("ui")

	_setDom: (dom, parseChild)->
		super(dom, parseChild)
		control = @get("control")
		dom.appendChild(control.getDom()) if control
		return

class dorado.menu.HeaderMenuItem extends dorado.menu.AbstractMenuItem
	@CLASS_NAME: "header item"
	@ATTRIBUTES:
		text: null

	_setDom: (dom, parseChild)->
		super(dom, parseChild)
		@get$Dom(@_text)if @_text
		return

	_doRefreshDom: ()->
		return unless @_dom
		super()
		@_classNamePool.remove("ui")
		text = @get("text") or ""
		@get$Dom().text(text)
		return

class dorado.Menu extends dorado.Widget
	@CLASS_NAME: "ui menu"
	@CHILDREN_TYPE_NAMESPACE: "menu"
	@SEMANTIC_CLASS: ["top fixed", "right fixed", "bottom fixed", "left fixed"]
	@ATTRIBUTES:
		items:
			setter: (value)->
				@clearItems() if @["_menuItems"]
				@["_items"] = value
				@addItem(item) for item in value if value
		showActivity:
			defaultValue: true
		rightItems:
			setter: (value)->
				@clearRightItems() if @["_rightItems"]
				@["_rightItems"] = value
				@addRightItem(item) for item in value if value

		centered:
			defaultValue: false
	@EVENTS:
		itemClick: null

	_parseDom: (dom)->
		child = dom.firstChild
		@_menuItems ?= []

		parseRightMenu = (node)=>
			childNode = node.firstChild
			@_rightMenuItems ?= []
			while childNode
				if childNode.nodeTypes == 1
					menuItem = dorado.widget(child)
					if menuItem
						menuItem._parent = @
						@_rightMenuItems.push(menuItem)
				childNode = childNode.nextSibling
			return

		parseItems = (node)=>
			childNode = node.firstChild
			while childNode
				if childNode.nodeType == 1
					menuItem = dorado.widget(childNode)
					if menuItem
						menuItem._parent = @
						@_menuItems.push(menuItem)

					else if !@_rightMenuDom and dorado.util.hasClass(childNode, "right menu")
						@_rightMenuDom = childNode
						parseRightMenu(childNode)
				childNode = childNode.nextSibling
			return
		container = $(dom).find(">.container")
		if container.length
			@_centered = true
			@_containerDom = container[0]
			parseItems(@_containerDom)
		else
			parseItems(dom)
		return

	_doRefreshDom: ()->
		return unless @_dom
		super()
		$(@_containerDom).toggleClass("ui container", !!@_centered)
		if @_isSubMemu then @_classNamePool.remove("ui")


		return

	_initDom: (dom)->
		menuItems = @_menuItems
		rightMenuItems = @_rightMenuItems
		menu = @
		if menuItems
			container = @_getItemsContainer()
			for item in menuItems
				itemDom = item.getDom()
				if itemDom.parentNode isnt container
					container.appendChild(itemDom)
		if rightMenuItems
			unless @_rightMenuDom
				@_rightMenuDom = @_createRightMenu()
				dom.appendChild(@_rightMenuDom)
			for item in rightMenuItems
				rItemDom = item.getDom()
				if rItemDom.parentNode isnt @_rightMenuDom
					@_rightMenuDom.appendChild(rItemDom)

		firstChild = dom.children[0]
		fragmentElement = $.xCreate({
			tagName: "div"
			class: "left-items"
		})
		if firstChild
			$(firstChild).before(fragmentElement)
		else
			dom.appendChild(fragmentElement)

		$(dom).hover(()=>
			@get$Dom().find(">.dropdown.item,.right.menu>.dropdown.item").each((index, item)=>
				$item = $(item)
				if $item.hasClass("d-dropdown") then return
				$item.addClass("d-dropdown")
				$item.find(".dropdown.item").addClass("d-dropdown")
				$item.dropdown({
					on: "hover"
				})
			)
			return
		).delegate(">.item,.right.menu>.item", "click", ()-> menu._setActive(this))
		return

	_setActive: (itemDom)->
		if @_parent and @_parent instanceof dorado.menu.DropdownMenuItem then return

		return unless @_showActivity
		$(">a.item:not(.dropdown),.right.menu>a.item:not(.dropdown)", @_dom).each(()->
			if itemDom is @
				$fly(@).addClass("active")
			else
				$fly(@).removeClass("active").find(".item").removeClass("active")
			return
		)

		return if $fly(itemDom).hasClass("dropdown")

		if $(">.menu", itemDom).length and !@_isSubMemu then $fly(itemDom).removeClass("active")
		return

	_getItemsContainer: ()->
		if @_centered
			unless @_containerDom
				@_containerDom = $.xCreate({tagName: "div", class: "container"})
				@_dom.appendChild(@_containerDom)

		return @_containerDom or @_dom
	getParent: ()-> @_parent
	onItemClick: (event, item)->
		parentMenu = @getParent()
		arg =
			item: item
			event: event
		@fire("itemClick", @, arg)
		return unless parentMenu
		if parentMenu instanceof dorado.menu.AbstractMenuItem or parentMenu instanceof dorado.Menu
			parentMenu.onItemClick(event, item)

		return

	_createItem: (config)->
		menuItem = null
		if config.constructor == Object.prototype.constructor
			if config.$type
				if config.$type is "dropdown"
					menuItem = new dorado.menu.DropdownMenuItem(config)
				else if config.$type is "headerItem"
					menuItem = new dorado.menu.HeaderMenuItem(config)
				else
					menuItem = new dorado.menu.ControlMenuItem({
						control: config
					})
			else
				menuItem = new dorado.menu.MenuItem(config)
		return menuItem

	addItem: (config)->
		menuItem = @_createItem(config)
		return unless menuItem
		menuItem._parent = @
		@_menuItems ?= []
		@_menuItems.push(menuItem)

		if @_dom
			container = @_getItemsContainer()
			itemDom = menuItem.getDom()
			if itemDom.parentNode isnt container
				if @_rightMenuDom
					$(@_rightMenuDom).before(menuItem.getDom())
				else
					container.appendChild(menuItem.getDom())
		return @

	addRightItem: (config)->
		menuItem = @_createItem(config)
		return @ unless menuItem
		menuItem._parent = @
		@_rightMenuItems ?= []
		@_rightMenuItems.push(menuItem)

		if @_dom
			container = @_getItemsContainer()
			itemDom = menuItem.getDom()

			unless @_rightMenuDom
				@_rightMenuDom = @_createRightMenu()

				container.appendChild(@_rightMenuDom)
			@_rightMenuDom.appendChild(itemDom) if itemDom.parentNode isnt @_rightMenuDom

		return @

	clearItems: ()->
		menuItems = @_menuItems
		if menuItems?.length
			item.destroy() for item in menuItems
			@_menuItems = []
		return @

	clearRightItems: ()->
		menuItems = @_rightMenuItems
		if menuItems?.length
			item.destroy() for item in menuItems
			@_rightMenuItems = []
		return @

	_doRemove: (array, item)->
		index = array.indexOf(item)
		if index > -1
			array.splice(index, 1)
			item.destroy()
		return

	removeItem: (item)->
		menuItems = @_menuItems
		return @ unless menuItems

		item = menuItems[item] if typeof item is "number"
		@_doRemove(menuItems, item) if item

		return @

	removeRightItem: (item)->
		menuItems = @_rightMenuItems
		return @ unless menuItems

		item = menuItems[item] if typeof item is "number"
		@_doRemove(menuItems, item) if item

		return @

	getItem: (index)->
		return @_menuItems?[index]

	getRightItem: (index)->
		return @_rightMenuItems?[index]

	_createRightMenu: ()->
		return $.xCreate(
			{
				tagName: "DIV"
				class: "right menu"
			}
		)


class dorado.TitleBar extends dorado.Menu
	@CLASS_NAME: "menu title-bar"
	@CHILDREN_TYPE_NAMESPACE: "menu"
	@ATTRIBUTES:
		title:
			refreshDom: true

	_parseDom: (dom)->
		child = dom.firstChild
		@_doms ?= {}
		while child
			if child.nodeType == 1
				if !@_doms.title and dorado.util.hasClass(child, "title")
					@_doms.title = child
					@_title ?= dorado.util.getTextChildData(child)
					break
			child = child.nextSibling

		super(dom)

		firstChild = dom.children[0]

		if @_doms.title and firstChild isnt @_doms.title
			$(@_doms.title).remove()
			$(firstChild).before(@_doms.title)

		return

	_doRefreshDom: ()->
		return unless  @_dom
		super()
		@_doms ?= {}
		if @_title
			unless @_doms.title
				@_doms.title = $.xCreate({
					tagName: "div"
					class: "title"
				})
				firstChild = @_dom.children[0]

				if firstChild
					$(firstChild).before(@_doms.title)
				else
					@_dom.appendChild(@_doms.title)
			$(@_doms.title).text(@_title)
		else
			$(@_doms.title).empty()

		return null

dorado.registerType("menu", "_default", dorado.menu.MenuItem)
dorado.registerType("menu", "item", dorado.menu.MenuItem)
dorado.registerType("menu", "dropdownItem", dorado.menu.DropdownMenuItem)
dorado.registerType("menu", "controlItem", dorado.menu.ControlMenuItem)
dorado.registerType("menu", "headerItem", dorado.menu.HeaderMenuItem)

dorado.registerTypeResolver "menu", (config) ->
	return dorado.resolveType("widget", config)






