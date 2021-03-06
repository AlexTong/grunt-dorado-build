class dorado.CardBook extends dorado.AbstractItemGroup
	@CLASS_NAME: "card-book"
	@EVENTS:
		beforeChange: null
		change: null

	_parseDom: (dom)->
		child = dom.firstChild
		while child
			if child.nodeType == 1
				if dorado.util.hasClass(child, "item")
					@addItem(child) if child.nodeType == 1
			child = child.nextSibling
		return null

	_setDom: (dom, parseChild)->
		super(dom, parseChild)
		@_itemsRender() if @_items
		return

	setCurrentIndex: (index)->
		@_currentIndex ?= -1
		return @ if @_currentIndex == index
		arg = {}

		if @_currentIndex > -1
			oldItem = @_items[@_currentIndex]
			oldItemDom = @getItemDom(@_currentIndex)
		if index > -1
			newItem = @_items[index]
			newItemDom = @getItemDom(index)

		arg =
			oldItem: oldItem
			newItem: newItem

		return @ if @fire("beforeChange", @, arg) is false

		$(oldItemDom).removeClass("active") if oldItemDom
		$(newItemDom).addClass("active") if newItemDom
		@_currentIndex = index

		@fire("change", @, arg)
		return @


