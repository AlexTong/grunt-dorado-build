#IMPORT_BEGIN
if exports?
	XDate = require("./../lib/xdate")
	dorado = require("./base")
	module?.exports = dorado
else
	XDate = @XDate
	dorado = @dorado
#IMPORT_END

if XDate
	$?(() ->
		XDate.defaultLocale = dorado.setting("locale") or defaultLocale
		XDate.locales[defaultLocale] = localeStrings = {}
		localeStrings.monthNames = dorado.i18n("dorado.date.monthNames").split(",") if dorado.i18n("dorado.date.monthNames")
		localeStrings.monthNamesShort = dorado.i18n("dorado.date.monthNamesShort").split(",") if dorado.i18n("dorado.date.monthNamesShort")
		localeStrings.dayNames = dorado.i18n("dorado.date.dayNames").split(",") if dorado.i18n("dorado.date.dayNames")
		localeStrings.dayNamesShort = dorado.i18n("dorado.date.dayNamesShort").split(",") if dorado.i18n("dorado.date.dayNamesShort")
		localeStrings.amDesignator = dorado.i18n("dorado.date.amDesignator") if dorado.i18n("dorado.date.amDesignator")
		localeStrings.pmDesignator = dorado.i18n("dorado.date.pmDesignator") if dorado.i18n("dorado.date.pmDesignator")
		return
	)

	XDate.parsers.push (str) ->
		if str.indexOf("||") < 0 then return

		parts = str.split("||")
		format = parts[0]
		dateStr = parts[1]

		parts =
			y: len: 0, value: 1900
			M: len: 0, value: 1
			d: len: 0, value: 1
			h: len: 0, value: 0
			m: len: 0, value: 0
			s: len: 0, value: 0
		patterns = []

		hasText = false
		inQuota = false
		i = 0
		while i < format.length
			c = format.charAt(i)
			if c == "\""
				hasText = true
				if inQuota == c
					inQuota = false
				else if !inQuota
					inQuota = c
			else if !inQuota and parts[c]
				if parts[c].len == 0 then patterns.push(c)
				parts[c].len++
			else
				hasText = true
			i++

		shouldReturn = false
		if !hasText
			if dateStr.match(/^\d{2,14}$/)
				shouldReturn = true
				start = 0
				for pattern in patterns
					part = parts[pattern]
					if part.len
						digit = dateStr.substring(start, start + part.len)
						part.value = parseInt(digit, 10)
						start += part.len
		else
			digits = dateStr.split(/\D+/)
			if digits[digits.length - 1] == "" then digits.splice(digits.length - 1, 1)
			if digits[0] == "" then digits.splice(0, 1)
			if patterns.length == digits.length
				shouldReturn = true
				for pattern, i in patterns
					parts[pattern].value = parseInt(digits[i], 10)

		if shouldReturn
			return new XDate(parts.y.value, parts.M.value - 1, parts.d.value, parts.h.value, parts.m.value, parts.s.value)
		else
			return