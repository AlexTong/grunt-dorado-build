#IMPORT_BEGIN
if exports?
	dorado = require("./entity")
	module?.exports = dorado
else
	dorado = @dorado
#IMPORT_END

dorado.convertor = {}

dorado.convertor["upper"] = (value) ->
	return value?.toUpperCase()

dorado.convertor["lower"] = (value) ->
	return value?.toLowerCase()

dorado.convertor["default"] = (value, defaultValue = "") ->
	return if value? then value else defaultValue

_matchValue = (value, propFilter) ->
	if propFilter.strict
		if !propFilter.caseSensitive and typeof propFilter.value == "string"
			return (value + "").toLowerCase() == propFilter.value
		else
			return value == propFilter.value
	else
		if !propFilter.caseSensitive
			return (value + "").toLowerCase().indexOf(propFilter.value) > -1
		else
			return (value + "").indexOf(propFilter.value) > -1

dorado.convertor["filter"] = (collection, criteria, params...) ->
	if !collection || !criteria then return collection

	if dorado.util.isSimpleValue(criteria)
		caseSensitive = params[0]
		if !caseSensitive then criteria = (criteria + "").toLowerCase()
		criteria =
			"$": {
				value: criteria
				caseSensitive: caseSensitive
				strict: params[1]
			}

	if typeof criteria == "object"
		for prop, propFilter of criteria
			if typeof propFilter == "string"
				criteria[prop] = {
					value: propFilter.toLowerCase()
				}
			else
				if dorado.util.isSimpleValue(propFilter)
					criteria[prop] = {
						value: propFilter
					}
				if !propFilter.strict
					propFilter.value = if propFilter.value then propFilter.value + "" else ""
				if !propFilter.caseSensitive and typeof propFilter.value == "string"
					propFilter.value = propFilter.value.toLowerCase()

		filtered = []
		dorado.each collection, (item) ->
			matches = false

			if dorado.util.isSimpleValue(item)
				if criteria.$
					matches = _matchValue(v, criteria.$)
			else
				for prop, propFilter of criteria
					if prop == "$"
						if item instanceof dorado.Entity
							data = item._data
						else
							data = item

						for p, v of data
							if _matchValue(v, propFilter)
								matches = true
								break
						if matches then break
					else if item instanceof dorado.Entity
						if _matchValue(item.get(prop), propFilter)
							matches = true
							break
					else
						if _matchValue(item[prop], propFilter)
							matches = true
							break
			if matches
				filtered.push(item)
			return
		return filtered
	else if typeof criteria == "function"
		filtered = []
		dorado.each collection, (item) ->
			filtered.push(item) if criteria(item, params...)
			return
		return filtered
	else
		return collection

_sortConvertor = (collection, comparator, caseSensitive) ->
	if !collection then return collection

	if collection instanceof dorado.EntityList
		collection = collection.toArray()

	if comparator
		if typeof comparator == "string"
			comparatorProps = []
			for part in comparator.split(",")
				c = part.charCodeAt(0)
				propDesc = false
				if c == 43 # `+`
					prop = part.substring(1)
				else if c == 45 # `-`
					prop = part.substring(1)
					propDesc = true
				else
					prop = part
				comparatorProps.push(prop: prop, desc: propDesc)

			comparator = (item1, item2) ->
				for comparatorProp in comparatorProps
					value1 = null
					value2 = null
					prop = comparatorProp.prop
					if prop
						if prop == "$random"
							return Math.random() * 2 - 1
						else
							if item1 instanceof dorado.Entity
								value1 = item1.get(prop)
							else if dorado.util.isSimpleValue(item1)
								value1 = item1
							else
								value1 = item1[prop]
							if !caseSensitive and typeof value1 == "string"
								value1 = value1.toLowerCase()

							if item2 instanceof dorado.Entity
								value2 = item2.get(prop)
							else if dorado.util.isSimpleValue(item2)
								value2 = item2
							else
								value2 = item2[prop]
							if !caseSensitive and typeof value2 == "string"
								value2 = value2.toLowerCase()

							result = 0
							if !value1? then result = -1
							else if !value2? then result = 1
							else if value1 > value2 then result = 1
							else if value1 < value2 then result = -1
							if result != 0
								return if comparatorProp.desc then (0 - result) else result
					else
						result = 0
						if !item1? then result = -1
						else if !item2? then result = 1
						else if item1 > item2 then result = 1
						else if item1 < item2 then result = -1
						if result != 0
							return if comparatorProp.desc then (0 - result) else result
				return 0
	else if comparator == "$none"
		return collection
	else
		comparator = (item1, item2) ->
			result = 0
			if !caseSensitive
				if typeof item1 == "string" then item1 = item1.toLowerCase()
				if typeof item2 == "string" then item2 = item2.toLowerCase()
			if !item1? then result = -1
			else if !item2? then result = 1
			else if item1 > item2 then result = 1
			else if item1 < item2 then result = -1
			return result

	comparatorFunc = (item1, item2) ->
		return comparator(item1, item2)
	return collection.sort(comparatorFunc)

dorado.convertor["orderBy"] = _sortConvertor
dorado.convertor["sort"] = _sortConvertor

dorado.convertor["date"] = (date, format) ->
	if !date? then return ""
	if not (date instanceof XDate)
		date = new XDate(date)
	return date.toString(format)

dorado.convertor["number"] = (number, format) ->
	if !number? then return ""
	return formatNumber(format, number)