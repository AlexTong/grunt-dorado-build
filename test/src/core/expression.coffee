#IMPORT_BEGIN
if exports?
	jsep = require("./../lib/jsep")
	dorado = require("./element")
	module?.exports = dorado
else
	jsep = @jsep
	dorado = @dorado
#IMPORT_END

dorado._compileText = (text) ->
	p = 0
	s = 0
	while (s = text.indexOf("{{", p)) > -1
		exprStr = digestExpression(text, s + 2)
		if exprStr
			if s > p
				if !parts then parts = []
				parts.push(text.substring(p, s))

			expr = dorado._compileExpression(exprStr, if exprStr.indexOf(" in ") > 0 then "repeat" else undefined)
			if !parts then parts = [expr] else parts.push(expr)
			p = s + exprStr.length + 4
		else
			break

	if parts
		if p < text.length - 1
			parts.push(text.substring(p))
		return parts
	else
		return null

digestExpression = (text, p) ->
	s = p
	len = text.length
	endBracket = 0
	while p < len
		c = text.charCodeAt(p)
		if c == 125 && !quota    # `}`
			if endBracket == 1
				return text.substring(s, p - 1)
			endBracket++
		else
			endBracket = 0
			if c == 39 || c == 34    # `'` or `"`
				if quota
					if quota == c then quota = false
				else
					quota = c
		p++
	return

dorado._compileExpression = (exprStr, specialType) ->
	if !exprStr then return null

	if specialType == "repeat"
		i = exprStr.indexOf(" in ")
		if i > 0
			aliasName = exprStr.substring(0, i)
			if aliasName.match(dorado.constants.VARIABLE_NAME_REGEXP)
				exprStr = exprStr.substring(i + 4)
				if !exprStr then return null
				exp = new dorado.Expression(exprStr, true)
				exp.raw = aliasName + " in " + exp.raw
				exp.repeat = true
				exp.alias = aliasName
				return exp
			throw new dorado.Exception("\"#{exprStr}\" is not a valid expression.")
		else
			exp = new dorado.Expression(exprStr, true)
			exp.repeat = true
			exp.alias = "item"
			return exp
	else if specialType == "alias"
		i = exprStr.indexOf(" as ")
		if i > 0
			aliasName = exprStr.substring(i + 4)
			if aliasName && aliasName.match(dorado.constants.VARIABLE_NAME_REGEXP)
				exprStr = exprStr.substring(0, i)
				if !exprStr then return null
				exp = new dorado.Expression(exprStr, true)
				exp.raw = exp.raw + " as " + aliasName
				exp.setAlias = true
				exp.alias = aliasName
				return exp
		throw new dorado.Exception("\"#{exprStr}\" should be a alias expression.")
	else
		return new dorado.Expression(exprStr, true)

splitExpression = (text, separator) ->
	separatorCharCode = separator.charCodeAt(0)
	parts = null
	p = 0
	i = 0
	len = text.length
	while i < len
		c = text.charCodeAt(i)
		if c == separatorCharCode && !quota
			part = text.substring(p, i)
			parts ?= []
			parts.push(dorado.util.trim(part))
			p = i + 1
		else
			if c == 39 || c == 34    # `'` or `"`
				if quota
					if quota == c then quota = false
				else
					quota = c
		i++

	if p < len
		part = text.substring(p)
		parts ?= []
		parts.push(dorado.util.trim(part))
	return parts

compileConvertor = (text) ->
	parts = splitExpression(text, ":")
	parts ?= [text]
	convertor = {
		name: parts[0]
		params: []
	}
	if parts.length > 1
		for part, i in parts
			if i == 0 then continue
			expr = new dorado.Expression(part)
			convertor.params.push(expr)
	return convertor

class dorado.Expression
	#path
	#hasCallStatement
	#convertors

	constructor: (exprStr, supportConvertor) ->
		@raw = exprStr

		if supportConvertor
			i = exprStr.indexOf("|")
			if 0 < i < (exprStr.length - 1)
				parts = splitExpression(exprStr, "|")
				if parts?.length > 1
					@convertors = []
					for part, i in parts
						if i == 0
							@compile(part)
							mainExprCompiled = true
						else
							@convertors.push(compileConvertor(part))

		@compile(exprStr) unless mainExprCompiled

		if supportConvertor and @convertors
			subPath = null
			for convertor in @convertors
				for param in convertor.params
					if param instanceof dorado.Expression and param.path
						subPath ?= []
						subPath = subPath.concat(param.path)

			if subPath
				if !@path
					@path = subPath
				else if typeof @path == "string"
					@path = [@path].concat(subPath)
				else
					@path = @path.concat(subPath)

	compile: (exprStr) ->
		stringifyMemberExpression = (node, parts, context) ->
			type = node.type
			if type == "Identifier"
				parts.push(node.name)
			else
				stringifyMemberExpression(node.object, parts, context)
				parts.push(node.property.name)
			return

		stringify = (node, parts, context) ->
			type = node.type
			switch type
				when "MemberExpression", "Identifier"
					pathPart = []
					stringifyMemberExpression(node, pathPart, context)
					path = pathPart.join(".")
					if !context.path
						context.path = path
					else if typeof context.path == "string"
						context.path = [context.path, path]
					else
						context.path.push(path)

					parts.push("_getData(scope,'")
					parts.push(path)
					parts.push("',loadMode,dataCtx)")

				when "CallExpression"
					context.hasCallStatement = true
					parts.push("scope.action(\"")
					stringifyMemberExpression(node.callee, parts, context)
					parts.push("\")(")
					if node.arguments?.length
						for argument, i in node.arguments
							if i > 0 then parts.push(",")
							stringify(argument, parts, context)
					parts.push(")")

				when "Literal"
					parts.push(node.raw)

				when "BinaryExpression", "LogicalExpression"
					parts.push("(")
					stringify(node.left, parts, context)
					parts.push(node.operator)
					stringify(node.right, parts, context)
					parts.push(")")

				when "ThisExpression"
					parts.push("scope")

				when "UnaryExpression"
					parts.push(node.operator)
					stringify(node.argument, parts, context)

				when "ConditionalExpression"
					parts.push("(")
					stringify(node.test, parts, context)
					parts.push("?")
					stringify(node.consequent, parts, context)
					parts.push(":")
					stringify(node.alternate, parts, context)
					parts.push(")")

				when "ArrayExpression"
					parts.push("[")
					for element, i in node.elements
						if i > 0 then parts.push(",")
						stringify(element, parts, context)
					parts.push("]")
			return

		tree = jsep(exprStr)
		@type = tree.type

		parts = []
		stringify(tree, parts, @)
		@expression = parts.join("")

	evaluate: (scope, loadMode, dataCtx)  ->
		retValue = eval(@expression)

		if retValue instanceof dorado.Entity or retValue instanceof dorado.EntityList
			dataCtx?.path = retValue.getPath()

		if @convertors
			dataCtx?.originData = retValue

			for convertorDef in @convertors
				convertor = dorado.convertor[convertorDef.name]
				if convertor
					args = [retValue]
					for paramExpr in convertorDef.params
						paramValue = paramExpr.evaluate(scope, "never")
						args.push(paramValue)
					retValue = convertor.apply(null, args)
				else
					throw new dorado.Exception("Unknown convert \"#{convertorDef.name}\".")
		return retValue

	toString: () ->
		return @expression

_getData = (scope, path, loadMode, dataCtx)  ->
	retValue = scope.get(path, loadMode, dataCtx)
	if retValue == undefined and dataCtx?.vars
		retValue = dataCtx.vars[path]
	return retValue