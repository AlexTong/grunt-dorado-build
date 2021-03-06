class dorado.Rating extends dorado.Widget
	@CLASS_NAME: "rating"
	@ATTRIBUTES:
		rating:
			defaultValue: 0
			refreshDom: true

		maxRating:
			refreshDom: true
			defaultValue: 1
			setter: (value)->
				@_maxRating = value
				@_refreshRating = true
		disabled:
			refreshDom: true
			defaultValue: false

		size:
			enum: ["mini", "tiny", "small", "medium", "large", "big", "huge", "massive"]
			refreshDom: true
			setter: (value)->
				oldValue = @["_size"]
				@get$Dom().removeClass(oldValue) if oldValue and oldValue isnt value and @_dom
				@["_size"] = value
				return

	@EVENTS:
		rate: null
	_fireRate: ()->
		dorado.util.cancelDelay(@, "_fireRate")
		@fire("rate", @, {rating: @_rating})
	_doRefreshRating: ()->
		@_refreshRating = false
		rating = @get("rating")
		maxRating = @get("maxRating")
		@_rating = rating = maxRating if rating > maxRating
		@get$Dom().empty().rating({
			initialRating: rating
			maxRating: maxRating
			onRate: (value)=>
				if value isnt @_rating
					@set("rating", value)
					dorado.util.delay(@, "_fireRate", 50, @_fireRate)
		}).rating(if @_disabled then "disable" else "enable")
		return
	_initDom: (dom)-> @_doRefreshRating()
	_doRefreshDom: ()->
		return unless @_dom
		super()
		if @_refreshRating
			@_doRefreshRating()
		else
			$dom = @get$Dom()
			$dom.rating(if @_disabled then "disable" else "enable")
			if $dom.rating("get rating") != @_rating
				$dom.rating("set rating", @_rating)
		return
	clear: ()->
		@set("rating", 0)
		return @


dorado.Element.mixin(dorado.Rating, dorado.DataWidgetMixin)