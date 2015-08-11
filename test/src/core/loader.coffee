dorado.loadSubView = (targetDom, context) ->
	loadingUrls = []
	failed = false

	resourceLoadCallback = (success, context, url) ->
		if success
			if not failed
				i = loadingUrls.indexOf(url)
				if i > -1 then loadingUrls.splice(i, 1)
				if loadingUrls.length == 0
					$fly(targetDom).removeClass("loading")
					if context.suspendedInitFuncs.length
						for initFunc in context.suspendedInitFuncs
							initFunc(targetDom, context.model, context.param)
					else
						dorado(targetDom, context.model)

					if dorado.getListeners("ready")
						dorado.fire("ready", dorado)
						dorado.off("ready")

					dorado.callback(context.callback, true)
		else
			failed = true
			error = context
			if dorado.callback(context.callback, false, error) != false
				if error.xhr
					errorMessage = error.status + " " + error.statusText
				else
					errorMessage = error.message
				throw new dorado.I18nException("dorado.error.loadResourceFailed", url, errorMessage)
		return

	$fly(targetDom).addClass("loading")

	# collect urls
	htmlUrl = context.htmlUrl
	if htmlUrl
		loadingUrls.push(htmlUrl)

	if context.jsUrl
		jsUrls = []
		if context.jsUrl instanceof Array
			for jsUrl in context.jsUrl
				jsUrl = _compileResourceUrl(jsUrl, htmlUrl, ".js")
				if jsUrl
					loadingUrls.push(jsUrl)
					jsUrls.push(jsUrl)
		else
			jsUrl = _compileResourceUrl(context.jsUrl, htmlUrl, ".js")
			if jsUrl
				loadingUrls.push(jsUrl)
				jsUrls.push(jsUrl)

	if context.cssUrl
		cssUrls = []
		if context.cssUrl instanceof Array
			for cssUrl in context.cssUrl
				cssUrl = _compileResourceUrl(cssUrl, htmlUrl, ".css")
				if cssUrl then cssUrls.push(cssUrl)
		else
			cssUrl = _compileResourceUrl(context.cssUrl, htmlUrl, ".css")
			if cssUrl then cssUrls.push(cssUrl)

	# load
	context.suspendedInitFuncs = []

	if htmlUrl
		_loadHtml(targetDom, htmlUrl, undefined, {
			callback: (success, result) -> resourceLoadCallback(success, (if success then context else result), htmlUrl)
		})

	if jsUrls
		for jsUrl in jsUrls
			_loadJs(context, jsUrl, {
				callback: (success, result) -> resourceLoadCallback(success, (if success then context else result), jsUrl)
			})

	if cssUrls
		_loadCss(cssUrl) for cssUrl in cssUrls
	return

_compileResourceUrl = (jsUrl, htmlUrl, suffix) ->
	if jsUrl == "$"
		jsUrl = null
		if htmlUrl
			i = htmlUrl.lastIndexOf(".")
			jsUrl = (if i > 0 then htmlUrl.substring(0, i) else htmlUrl) + suffix
	return jsUrl

_loadHtml = (targetDom, url, data, callback) ->
	$(targetDom).load(url, data,
		(response, status, xhr) ->
			if status == "error"
				dorado.callback(callback, false, {
					xhr: xhr
					status: xhr.status
					statusText: xhr.statusText
				})
			else
				dorado.callback(callback, true)
			return
	)
	return

_jsCache = {}

_loadJs = (context, url, callback) ->
	initFuncs = _jsCache[url]
	if initFuncs
		Array.prototype.push.apply(context.suspendedInitFuncs, initFuncs)
		dorado.callback(callback, true)
	else
		$.ajax(
			url: url
			dataType: "text"
			cache: true
			success: (script) ->
				scriptElement = $.xCreate(
					tagName: "script"
					language: "javascript"
					type: "text/javascript"
					charset: dorado.setting("defaultCharset")
				)
				scriptElement.text = script
				dorado._suspendedInitFuncs = context.suspendedInitFuncs
				try
					try
						head = document.querySelector("head") or document.documentElement
						head.appendChild(scriptElement)
					finally
						delete dorado._suspendedInitFuncs
						_jsCache[url] = context.suspendedInitFuncs
					dorado.callback(callback, true)
				catch e
					dorado.callback(callback, false, e)
				return
			error: (xhr) ->
				dorado.callback(callback, false, {
					xhr: xhr
					status: xhr.status
					statusText: xhr.statusText
				})
				return
		)
	return

_cssCache = {}

_loadCss = (url) ->
	if not _cssCache[url]
		linkElement = $.xCreate(
			tagName: "link"
			rel: "stylesheet"
			type: "text/css"
			charset: dorado.setting("defaultCharset")
			href: url
		)
		head = document.querySelector("head") or document.documentElement
		head.appendChild(linkElement)
		_cssCache[url] = true
	return