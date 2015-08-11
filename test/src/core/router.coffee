routerRegistry = null
currentPath = null

trimPath = (path) ->
	if path
		if path.charCodeAt(0) == 47 # `/`
			path = path.substring(1)
		if path.charCodeAt(path.length - 1) == 47 # `/`
			path = path.substring(0, path.length - 1)
	return path

# routerDef.path
# routerDef.redirectTo
# routerDef.enter
# routerDef.leave
# routerDef.title
# routerDef.jsUrl
# routerDef.templateUrl
# routerDef.target
# routerDef.model
# routerDef.parentModel

dorado.router = (name, config) ->
	if config
		routerRegistry ?= new dorado.util.KeyedArray()

		if typeof config == "function"
			routerDef = config
		else
			routerDef = {name: name}
			routerDef[p] = v for p, v of config

		routerDef.path ?= name
		routerDef.model ?= name

		path = trimPath(routerDef.path) or dorado.constants.DEFAULT_PATH
		if path
			hasVariable = false
			routerDef.pathParts = pathParts = []
			for part in path.split("/")
				if part.charCodeAt(0) == 58 # `:`
					hasVariable = true
					pathParts.push({
						variable: part.substring(1)
					})
				else
					pathParts.push(part)
			routerDef.hasVariable = hasVariable

		routerRegistry.add(name, routerDef)
		return @
	else
		return routerRegistry?.get(name)

dorado.removeRouter = (path) ->
	routerRegistry?.remove(path)
	return

dorado.setRouterPath = (path) ->
	if path.charCodeAt(0) == 35 # `#`
		routerMode = "hash"
		path = path.substring(1)

	if routerMode is "hash"
		if path.charCodeAt(0) != 47 # `/`
			path = "/" + path
		window.location.hash = path if window.location.hash != path
	else
		window.history.pushState({
			path: path
		}, null, path)
		_onStateChange(path)
	return

_findRouter = (path) ->
	return null unless routerRegistry

	pathParts = path.split("/")
	for routerDef in routerRegistry.elements
		if routerDef.pathParts.length != pathParts.length
			continue

		matching = true
		param = {}
		defPathParts = routerDef.pathParts
		for defPart, i in defPathParts
			if typeof defPart == "string"
				if defPart != pathParts[i]
					matching = false
					break
			else
				param[defPart.variable] = pathParts[i]
		if matching then break

	if matching
		routerDef.param = param
		return routerDef
	else
		return null

_switchRouter = (routerDef) ->
	if typeof routerDef == "function"
		routerDef()
		return

	if routerDef.redirectTo
		dorado.setRouterPath(routerDef.redirectTo)
		return

	if _currentRouterDef
		oldModel = dorado.model(_currentRouterDef.name)
		_currentRouterDef.leave?(_currentRouterDef, oldModel)
		oldModel?.destroy()

	if routerDef.templateUrl
		if routerDef.target
			if routerDef.target.nodeType
				target = routerDef.target
			else
				target = $(routerDef.target)[0]
		if !target
			target = document.getElementsByClassName(dorado.constants.VIEW_PORT_CLASS)[0]
			if !target
				target = document.getElementsByClassName(dorado.constants.VIEW_CLASS)[0]
				if !target
					target = document.body
		routerDef.targetDom = target
		$fly(target).empty()

	_currentRouterDef = routerDef

	if typeof routerDef.model == "string"
		model = dorado.model(routerDef.model)
	else if routerDef.model instanceof dorado.Model
		model = routerDef.model

	if !model
		parentModelName = routerDef.parentModel or dorado.constants.DEFAULT_PATH
		parentModel = dorado.model(parentModelName)
		if !parentModel then throw new dorado.Exception("Parent Model \"#{parentModelName}\" is undefined.")
		routerDef.model = model = new dorado.Model(routerDef.model, parentModel)

	if routerDef.templateUrl
		dorado.loadSubView(routerDef.targetDom,
			{
				model: model
				htmlUrl: routerDef.templateUrl
				jsUrl: routerDef.jsUrl
				cssUrl: routerDef.cssUrl
				data: routerDef.data
				param: routerDef.param
				callback: (success) ->
					if success
						routerDef.enter?(routerDef, model)
						document.title = routerDef.title if routerDef.title
					return
			})
	else
		routerDef.enter?(routerDef, model)
		document.title = routerDef.title if routerDef.title
	return

_getHashPath = () ->
	path = location.hash
	path = path.substring(1) if path

	if path?.charCodeAt(0) == 33 # `!`
		path = path.substring(1)
	path = trimPath(path)
	return path

_onHashChange = () ->
	path = _getHashPath() or dorado.constants.DEFAULT_PATH
	return if path == currentPath
	currentPath = path

	routerDef = _findRouter(path)
	_switchRouter(routerDef) if routerDef
	return

_onStateChange = (path = dorado.constants.DEFAULT_PATH) ->
	return if path == currentPath
	currentPath = path

	routerDef = _findRouter(path)
	_switchRouter(routerDef) if routerDef
	return

$ () ->
	setTimeout(() ->
		$fly(window).on("hashchange", _onHashChange).on("popstate", () ->
			state = window.history.state
			if state
				path = state.path
				_onStateChange(path)
			return
		)
		$(document.body).delegate("a.state", "click", () ->
			dorado.setRouterPath(@getAttribute("href"))
			return false
		)

		path = _getHashPath() or dorado.setting("defaultRouterPath")
		routerDef = _findRouter(path)
		if routerDef
			currentPath = path
			_switchRouter(routerDef)
		return
	, 0)
	return