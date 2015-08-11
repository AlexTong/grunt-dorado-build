class dorado.SubView extends dorado.Widget
	@CLASS_NAME: "sub-view"

	@ATTRIBUTES:
		loading: null
		url:
			readOnlyAfterCreate: true
		jsUrl:
			readOnlyAfterCreate: true
		cssUrl:
			readOnlyAfterCreate: true
		model:
			readOnly: true
			getter: () ->
				return if @_dom then dorado.util.userData(@_dom, "_model") else null
		param:
			readOnlyAfterCreate: true

	@EVENTS:
		load: null
		loadError: null
		unload: null

	_initDom: (dom)->
		if @_url
			@load(
				url: @_url
				jsUrl: @_jsUrl
				cssUrl: @_cssUrl
				param: @_param
			)
		return

	load: (options, callback) ->
		dom = @_dom
		@unload()

		model = new dorado.Model(@_scope)
		dorado.util.userData(dom, "_model", model)

		@_url = options.url
		@_jsUrl = options.jsUrl
		@_cssUrl = options.cssUrl
		@_param = options.param

		@_loading = true
		dorado.loadSubView(@_dom,
			{
				model: model
				htmlUrl: @_url
				jsUrl: @_jsUrl
				cssUrl: @_cssUrl
				param: @_param
				callback: {
					callback:(success, result) =>
						@_loading = false
						if success
							@fire("load", @)
						else
							@fire("loadError", @, {
								error: result
							})
						dorado.callback(callback, success, result)
						return
				}
			})
		return

	loadIfNecessary: (options, callback) ->
		if @_url == options.url
			dorado.callback(callback, true)
		else
			@load(options, callback)
		return

	unload: () ->
		dom = @_dom

		delete @_url
		delete @_jsUrl
		delete @_cssUrl
		delete @_param

		model = dorado.util.userData(dom, "_model")
		model?.destroy()
		dorado.util.removeUserData(dom, "_model")
		$fly(dom).empty()
		@fire("unload", @)
		return

