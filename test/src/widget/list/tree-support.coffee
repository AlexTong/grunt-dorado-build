_getEntityId = dorado.Entity._getEntityId

class dorado.CascadeBind extends dorado.Element
	@ATTRIBUTES:
		name: null
		expression:
			setter: (expression) ->
				expression = dorado._compileExpression(expression, "repeat")
				if expression
					if !expression.repeat
						throw new dorado.I18nException("dorado.error.needRepeatBinding", bindStr)
				else
					delete @_alias
				@_expression = expression
				return

		recursive: null
		child:
			setter: (child) ->
				if child and !(child instanceof dorado.CascadeBind)
					child = new dorado.CascadeBind(@_widget, child)
				@_child = child
				return

		hasChildProperty: null

	constructor: (widget, config) ->
		@_widget = widget
		super(config)

	_wrapChildItems: (parentNode, recursiveItems, originRecursiveItems, childItems, originChildItems) ->
		nodes = []
		nodeType = @constructor.NODE_TYPE

		nodeCache = parentNode._nodeMap
		nodeMap = {}

		if recursiveItems
			dorado.each recursiveItems, (item) =>
				if nodeCache
					id = _getEntityId(item)
					if id
						node = nodeCache[id]
						if node?._bind == @
							delete nodeCache[id]
						else
							node = null

				node ?= new nodeType(@, item)
				node._parent = parentNode
				nodeMap[node._id] = node
				nodes.push(node)
				return
		if childItems
			dorado.each childItems, (item) =>
				if nodeCache
					id = _getEntityId(item)
					if id
						node = nodeCache[id]
						if node?._bind == @
							delete nodeCache[id]
						else
							node = null

				node ?= new nodeType(@_child, item)
				node._parent = parentNode
				node._scope = parentNode._scope
				nodes.push(node)
				return

		for id, node of nodeCache
			node.destroy()

		parentNode._nodeMap = nodeMap
		parentNode._children = nodes
		delete parentNode._hasChild

		itemsScope = parentNode._itemsScope
		if itemsScope
			args = [nodes]
			if recursiveItems
				args.push(originRecursiveItems or recursiveItems)
			if childItems
				args.push(originChildItems or childItems)
			itemsScope._setItems.apply(itemsScope, args)
		return

	retrieveChildNodes: (parentNode, callback) ->
		isRoot = !parentNode._parent
		hasChild = false
		funcs = []
		if @_recursive or isRoot
			dataCtx = {}
			items = @_expression.evaluate(parentNode._scope, "auto", dataCtx)
			if items == undefined and dataCtx.unloaded
				recursiveLoader = dataCtx.providerInvokers?[0]
				if recursiveLoader
					funcs.push((callback) -> recursiveLoader.invokeAsync(callback))
			else
				recursiveItems = items
				originRecursiveItems = dataCtx.originData
				if recursiveItems
					if recursiveItems instanceof dorado.EntityList
						hasChild = recursiveItems.entityCount > 0
					else
						hasChild = recursiveItems.length > 0

		if @_child and !isRoot
			dataCtx = {}
			items = @_child._expression.evaluate(parentNode._scope, "auto", dataCtx)
			if items == undefined and dataCtx.unloaded
				childLoader = dataCtx.providerInvokers?[0]
				if childLoader
					funcs.push((callback) -> childLoader.invokeAsync(callback))
			else
				childItems = items
				originChildItems = dataCtx.originData
				hasChild = true

		if funcs.length and callback
			dorado.util.waitForAll(funcs, {
				callback: (success, result) =>
					if success
						hasChild = false
						if @_recursive or isRoot
							dataCtx = {}
							recursiveItems = @_expression.evaluate(parentNode._scope, "never", dataCtx)
							originRecursiveItems = dataCtx.originData
							if recursiveItems
								if recursiveItems instanceof dorado.EntityList
									hasChild = recursiveItems.entityCount > 0
								else
									hasChild = recursiveItems.length > 0
						if @_child and !isRoot
							hasChild = true
							dataCtx = {}
							childItems = @child._expression.evaluate(parentNode._scope, "never", dataCtx)
							originChildItems = dataCtx.originData

						if hasChild
							@_wrapChildItems(parentNode, recursiveItems, originRecursiveItems, childItems,
								originChildItems)
						else
							parentNode._hasChild = false
						parentNode._itemsScope.onItemsRefresh?()
						dorado.callback(callback, true)
					else
						dorado.callback(callback, false, result)
					return
			})
		else
			if hasChild
				@_wrapChildItems(parentNode, recursiveItems, originRecursiveItems, childItems, originChildItems)
			else
				parentNode._hasChild = false
			parentNode._itemsScope.onItemsRefresh?()
			if callback
				dorado.callback(callback, true)
		return

	hasChildItems: (parentScope) ->
		if @_recursive
			dataCtx = {}
			items = @_expression.evaluate(parentScope, "never", dataCtx)
			if !dataCtx.unloaded
				if items
					if items instanceof dorado.EntityList
						hasChild = items.entityCount > 0
					else
						hasChild = items.length > 0
					return true if hasChild
			else
				return

		if @_child
			dataCtx = {}
			items = @_child._expression.evaluate(parentScope, "never", dataCtx)
			if !dataCtx.unloaded
				if items
					if items instanceof dorado.EntityList
						hasChild = items.entityCount > 0
					else
						hasChild = items.length > 0
					return true if hasChild
			else
				return
		return false

class dorado.Node extends dorado.Element
	isDataWrapper: true

	@ATTRIBUTES:
		bind:
			readOnly: true
		alias: null
		data: null
		hasChild:
			getter: () ->
				return true if @_children?.length > 0
				return @_hasChild if @_hasChild?

				bind = @_bind
				prop = bind._hasChildProperty
				if prop and @_data
					if @_data instanceof dorado.Entity
						return @_data.get(prop, "never")
					else
						return @_data[prop]

				if @_scope
					if bind._recursive
						dataCtx = {}
						items = bind._expression.evaluate(@_scope, "never", dataCtx)
						if dataCtx.unloaded then return
						if !items then return false
					if bind._child
						dataCtx = {}
						items = bind.child._expression.evaluate(@_scope, "never", dataCtx)
						if dataCtx.unloaded then return
						if !items then return false
				return

		parent:
			readOnly: true
		children:
			readOnly: true

	constructor: (bind, data) ->
		super()
		@_bind = bind
		@_alias = bind._expression?.alias
		@_widget = bind._widget

		@_data = data
		if typeof data == "object"
			@_id = dorado.Entity._getEntityId(data)
		else
			@_id = dorado.uniqueId()

		@_widget?._onNodeAttach?(@)

	destroy: () ->
		if @_children
			for child in @_children
				child.destroy()
		@_widget?._onNodeDetach?(@)
		return

	remove: () ->
		if @_parent
			parent = @_parent
			i = parent._children.indexOf(@)
			if i > -1
				parent._children.splice(i, 1)
			delete parent._nodeMap[@_id]
		@destroy()
		return

dorado.TreeSupportMixin =
	constructor: () ->
		@_nodeMap = {}

	_onNodeAttach: (node) ->
		@_nodeMap[node._id] = node
		return

	_onNodeDetach: (node) ->
		delete @_nodeMap[node._id]
		return

