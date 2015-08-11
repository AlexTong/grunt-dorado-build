
class dorado.Search extends dorado.Widget
	@CLASS_NAME: "ui search"
	@ATTRIBUTES:
		value: null
		placeholder: null
		source:
			setter: (value)->
				@_source = value
				@_resetSource(value) if @_dom
				return

	@EVENTS:
		onResults: null
		onSearchQuery: null
		onResultsOpen: null
		onResultsClose: null
		onSelect: null

	_parseInputContainer: (node)->
		child = node.firstChild
		@_doms ?= {}
		while child
			if child.nodeType == 1
				if child.nodeName == "INPUT"
					@_doms.input = child
				else if child.nodeName == "I"
					@_doms.icon = child
					$(icon).addClass("search icon")
			child = child.nextSibling

		return

	_parseDom: (dom)->
		child = dom.firstChild

		@_doms ?= {}
		while child
			if child.nodeType == 1
				if dorado.util.hasClass(child, "ui input")
					@_doms.inputContainer = child
					$(child).addClass("ui icon input")
				else if dorado.util.hasClass("results")
					@_doms.results = child
			child = child.nextSibling

		unless @_doms.inputContainer
			containerDom = $.xCreate({
				tagName: "div"
				class: "ui icon input"
				contextKey:"inputContainer"
				content: [
					{
						tagName: "input"
						class: "prompt"
						type: "text"
						placeholder: @_placeholder or ""
						contextKey:"input"
					}
					{
						tagName: "i"
						class: "search icon"
						contextKey:"icon"
					}
				]
			}, @_doms)

			if @_doms.results
				$(@_doms.results).before(containerDom)
			else
				dom.appendChild(containerDom)

		unless @_doms.results
			@_doms.results = $.xCreate({
				tagName: "div"
				class: "results"
			})

			dom.appendChild(@_doms.results)

		unless @_doms.input
			@_doms.input = $.xCreate({
				tagName: "input"
				class: "prompt"
				type: "text"
				placeholder: @_placeholder or ""
			})

			@_doms.inputContainer.appendChild(@_doms.input)

		unless @_doms.icon
			@_doms.icon = $.xCreate({
				tagName: "i"
				class: "search icon"
			})

			@_doms.inputContainer.appendChild(@_doms.icon)

		return

	_createDom: ()->
		placeholder = @get("placeholder") or ""
		return $.xCreate(
			{
				tagName: "div"
				class: @constructor.CLASS_NAME
				content: [
					{
						tagName: "div"
						class: "ui icon input"
						content: [
							{
								tagName: "input"
								class: "prompt"
								type: "text"
								placeholder: placeholder
							}
							{
								tagName: "i"
								class: "search icon"
							}
						]
					}
					{
						tagName: "div"
						class: "results"
					}
				]
			}, @_doms)

	_setDom: (dom, parseChild)->
		super(dom, parseChild)

		@get$Dom().search({
			source: @_source or []
			onResults: (res)=>
				arg =
					results: res
					event: window.event
				@fire("onResults", @, arg)

			onSearchQuery: (searchTerm)=>
				@_value = searchTerm
				arg =
					searchTerm: searchTerm
					event: window.event
				@fire("onSearchQuery", @, arg)

			onResultsOpen: ()=>
				arg =
					event: window.event
				@fire("onResultsOpen", @, arg)

			onResultsClose: ()=>
				arg =
					event: window.event
				@fire("onResultsClose", @, arg)

			onSelect: (result, results)=>
				@_value = result.title
				arg =
					event: window.event
					result: result
					results: results

				@fire("onSelect", @, arg)
		})

		return

	_resetSource: ()->
		source = @get("source") or []
		$(@_doms.results).empty()
		@get$Dom().search("setting source", source)

		return

	getDom: ()->
		return null if @_destroyed
		unless @_dom
			@_doms = {}
			super()
			@_resetSource()

		return @_dom