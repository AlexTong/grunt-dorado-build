#IMPORT_BEGIN
if exports?
	dorado = require("./util")
	module?.exports = dorado
else
	dorado = @dorado
#IMPORT_END

_$ = $()
_$.length = 1
this.$fly = (dom) ->
	_$[0] = dom
	return _$

doms = {}
dorado.util.cacheDom = (ele) ->
	if !doms.hiddenDiv
		doms.hiddenDiv = $.xCreate(
			tagName: "div"
			id: "_d_hidden_div"
			style:
				display: "none"
		)
		doms.hiddenDiv.setAttribute(dorado.constants.IGNORE_DIRECTIVE, "")
		document.body.appendChild(doms.hiddenDiv)
	dorado._ignoreNodeRemoved = true
	doms.hiddenDiv.appendChild(ele)
	dorado._ignoreNodeRemoved = false
	return

USER_DATA_KEY = dorado.constants.DOM_USER_DATA_KEY

dorado.util.userDataStore = {}

dorado.util.userData = (node, key, data) ->
	return if node.nodeType == 3
	userData = dorado.util.userDataStore
	if node.nodeType == 8
		text = node.nodeValue
		i = text.indexOf("|")
		id = text.substring(i + 1) if i > -1
	else
		id = node.getAttribute(USER_DATA_KEY)

	if arguments.length == 3
		if !id
			id = dorado.uniqueId()
			if node.nodeType == 8
				if i > -1
					node.nodeValue = text.substring(0, i + 1) + id
				else
					node.nodeValue = if text then text + "|" + id else "|" + id
			else
				node.setAttribute(USER_DATA_KEY, id)

			userData[id] = store = {}
		else
			store = userData[id]
			if !store then userData[id] = store = {}

		store[key] = data
	else if arguments.length == 2
		if typeof key == "string"
			if id
				store = userData[id]
				return store?[key]
		else if key and typeof key == "object"
			id = dorado.uniqueId()
			if node.nodeType == 8
				if i > -1
					node.nodeValue = text.substring(0, i + 1) + id
				else
					node.nodeValue = if text then text + "|" + id else "|" + id
			else
				node.setAttribute(USER_DATA_KEY, id)

			userData[id] = key
	else if arguments.length == 1
		if id
			return userData[id]
	return

dorado.util.removeUserData = (node, key) ->
	id = node.getAttribute(USER_DATA_KEY)
	if id
		store = dorado.util.userDataStore[id]
		if store
			delete store[key]
	return

ON_NODE_REMOVED_KEY = "__onNodeRemoved"

dorado.detachNode = (node) ->
	return unless node.parentNode
	dorado._ignoreNodeRemoved = true
	node.parentNode.removeChild(ele)
	dorado._ignoreNodeRemoved = false
	return

dorado.util.onNodeRemoved = (node, listener) ->
	oldListener = dorado.util.userData(node, ON_NODE_REMOVED_KEY)
	if oldListener
		if oldListener instanceof Array
			oldListener.push(listener)
		else
			dorado.util.userData(node, ON_NODE_REMOVED_KEY, [oldListener, listener])
	else
		dorado.util.userData(node, ON_NODE_REMOVED_KEY, listener)
	return

_removeNodeData = (node) ->
	return if node.nodeType == 3

	if node.nodeType == 8
		text = node.nodeValue
		i = text.indexOf("|")
		id = text.substring(i + 1) if i > -1
	else
		id = node.getAttribute(USER_DATA_KEY)

	if id
		store = dorado.util.userDataStore[id]
		if store
			nodeRemovedListener = store[ON_NODE_REMOVED_KEY]
			if nodeRemovedListener
				if nodeRemovedListener instanceof Array
					for listener in nodeRemovedListener
						listener(node, store)
				else
					nodeRemovedListener(node, store)
			delete dorado.util.userDataStore[id]
	return

_DOMNodeRemovedListener = (evt) ->
	return if dorado._ignoreNodeRemoved or window.closed

	node = evt.target
	return unless node

	child = node.firstChild
	while child
		_removeNodeData(child)
		child = child.nextSibling

	_removeNodeData(node)
	return

document.addEventListener("DOMNodeRemoved", _DOMNodeRemovedListener)

$fly(window).on("unload", () ->
	document.removeEventListener("DOMNodeRemoved", _DOMNodeRemovedListener)
	return
)

if dorado.device.mobile
	$fly(window).on("load", () ->
		FastClick.attach(document.body)
		return
	)

if dorado.browser.webkit
	browser = "webkit"
	if dorado.browser.chrome
		browser += " chrome"
	else if dorado.browser.safari
		browser += " safari"
	else if dorado.browser.qqbrowser
		browser += " qqbrowser"
else if dorado.browser.ie
	browser = "ie"
else if dorado.browser.mozilla
	browser = "mozilla"
else
	browser = ""

if dorado.os.android
	os = " android"
else if dorado.os.ios
	os = " ios"
else if dorado.os.windows
	os = " windows"
else
	os = ""

if dorado.device.mobile
	os += " mobile"
else if dorado.device.desktop
	os += " desktop"

if browser or os
	$fly(document.documentElement).addClass(browser + os)

if dorado.os.mobile
	$ () ->
		FastClick?.attach(document.body)
		return
