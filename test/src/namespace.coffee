dorado = () ->
	return dorado["_rootFunc"]?.apply(dorado, arguments)

module?.exports = dorado
this.dorado = dorado

dorado.util = {}

dorado.constants = {
	VARIABLE_NAME_REGEXP: /^[_a-zA-Z][_a-zA-Z0-9]*$/g

	VIEW_CLASS: "d-view"
	VIEW_PORT_CLASS: "d-viewport"
	IGNORE_CLASS: "dorado-ignore"

	COLLECTION_CURRENT_CLASS: "current"

	DEFAULT_PATH: "$root"

	DOM_USER_DATA_KEY: "_d"
	DOM_BINDING_KEY: "binding"
	DOM_INITIALIZER_KEY: "initialize"
	REPEAT_TEMPLATE_KEY: "template"
	REPEAT_TAIL_KEY: "tail"
	DOM_WIDGET_KEY: "widget"

	NOT_WHITE_REG: /\S+/g
	CLASS_REG: /[\t\r\n\f]/g
	WIDGET_DIMENSION_UNIT: "px"

	MESSAGE_REFRESH: 0
	MESSAGE_DATA_CHANGE: 1

	MESSAGE_CURRENT_CHANGE: 10
	MESSAGE_STATE_CHANGE: 11

	MESSAGE_INSERT: 20
	MESSAGE_REMOVE: 21

	MESSAGE_LOADING_START: 30
	MESSAGE_LOADING_END: 31
}
