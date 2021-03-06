class dorado.Table extends dorado.AbstractTable
	@CLASS_NAME: "items-view widget-table"

	_initDom: (dom) ->
		super(dom)
		$fly(window).resize () =>
			if @_fixedHeaderVisible
				fixedHeader = @_getFixedHeader()
				$fly(fixedHeader).width(@_doms.itemsWrapper.clientWidth)
			if @_fixedFooterVisible
				fixedFooter = @_getFixedFooter()
				$fly(fixedFooter).width(@_doms.itemsWrapper.clientWidth)
			return
		return

	_doRefreshItems: () ->
		colgroup = @_doms.colgroup
		nextCol = colgroup.firstChild
		for colInfo, i in @_columnsInfo.dataColumns
			col = nextCol
			if !col
				col = document.createElement("col")
				colgroup.appendChild(col)
			else
				nextCol = col.nextSibling

			if colInfo.widthType == "precent"
				col.width = colInfo.width + "%"
			else if colInfo.widthType
				col.width = colInfo.width + colInfo.widthType
			else if colInfo.width
				col.width = (colInfo.width * 100 / @_columnsInfo.totalWidth) + "%"
			else
				col.width = ""

			column = colInfo.column
			col.valign = column._valign or ""

		col = nextCol
		while col
			nextCol = col.nextSibling
			colgroup.removeChild(col)
			col = nextCol

		tbody = @_doms.tbody

		if @_showHeader
			thead = @_doms.thead
			if !thead
				$fly(tbody).xInsertBefore({
					tagName: "thead"
					contextKey: "thead"
				}, @_doms)
				thead = @_doms.thead
			@_refreshHeader(thead)

		super(tbody)

		if @_showFooter
			tfoot = @_doms.tfoot
			if !tfoot
				$fly(tbody).xInsertAfter({
					tagName: "tfoot"
					contextKey: "tfoot"
				}, @_doms)
				tfoot = @_doms.tfoot
			@_refreshFooter(tfoot)

			if !@_fixedFooterVisible
				@_showFooterTimer = setInterval(() =>
					itemsWrapper = @_doms.itemsWrapper
					if itemsWrapper.scrollHeight
						@_refreshFixedFooter(300)
					return
				, 300)
		return

	_onItemInsert: (arg) ->
		super(arg)

		if @_columnsInfo.selectColumns
			dorado.util.delay(@, "refreshHeaderCheckbox", 100, () =>
				for colInfo in @_columnsInfo.selectColumns
					colInfo.column.refreshHeaderCheckbox()
				return
			)
		return

	_onItemRemove: (arg) ->
		super(arg)
		@_refreshFixedFooter() if @_showFooter

		if @_columnsInfo.selectColumns
			dorado.util.delay(@, "refreshHeaderCheckbox", 100, () =>
				for colInfo in @_columnsInfo.selectColumns
					colInfo.column.refreshHeaderCheckbox()
				return
			)
		return

	_refreshHeader: (thead) ->
		fragment = null
		rowInfos = @_columnsInfo.rows
		i = 0
		len = rowInfos.length
		while i < len
			row = thead.rows[i]
			if !row
				row = $.xCreate(
					tagName: "tr"
				)
				fragment ?= document.createDocumentFragment()
				fragment.appendChild(row)

			rowInfo = rowInfos[i]
			for colInfo, j in rowInfo
				column = colInfo.column
				cell = row.cells[j]
				while cell and cell._name != column._name
					row.removeChild(cell)
					cell = row.cells[j]

				if !cell
					isNew = true
					cell = $.xCreate({
						tagName: "th"
						content:
							tagName: "div"
					})
					cell._name = column._name
					row.appendChild(cell)
				cell._index = colInfo.index
				if colInfo.columns
					cell.rowSpan = 1
					cell.colSpan = colInfo.columns.length
				else
					cell.rowSpan = len - i
					cell.colSpan = 1
				contentWrapper = cell.firstChild

				@_refreshHeaderCell(contentWrapper, colInfo, isNew)

			while row.lastChild != cell
				row.removeChild(row.lastChild)
			i++

		while row.lastChild != cell
			row.removeChild(row.lastChild)

		dorado.xRender(row, @_scope)
		if fragment then thead.appendChild(fragment)
		while thead.lastChild != row
			thead.removeChild(thead.lastChild)
		return

	_refreshHeaderCell: (dom, columnInfo, isNew) ->
		column = columnInfo.column

		if column.renderHeader
			if column.renderHeader(dom) != true
				return

		if column.getListeners("renderHeader")
			if column.fire("renderHeader", column, {dom: dom}) == false
				return

		if @getListeners("renderHeader")
			if @fire("renderHeader", @, {column: column, dom: dom}) == false
				return

		if isNew
			template = column._realHeaderTemplate
			if template == undefined
				templateName = column._headerTemplate
				if templateName
					template = @_getTemplate(templateName)
				column._realHeaderTemplate = template or null
			if template
				template = @_cloneTemplate(template)
				dom.appendChild(template)
		return if column._realHeaderTemplate

		dataType = @_getBindDataType()
		if dataType and columnInfo.property
			propertyDef = dataType.getProperty(columnInfo.property)

		caption = column._caption or propertyDef?._caption
		if !caption
			caption = column._name
			if caption?.charCodeAt(0) == 95 # `_`
				caption = column._bind
		dom.innerText = caption or ""
		return

	_refreshFooter: (tfoot) ->
		colInfos = @_columnsInfo.dataColumns
		row = tfoot.rows[0]
		if !row
			row = document.createElement("tr")
		for colInfo, i in colInfos
			column = colInfo.column
			cell = row.cells[i]
			while cell and cell._name != column._name
				row.removeChild(cell)
				cell = row.cells[i]

			if !cell
				isNew = true
				cell = $.xCreate({
					tagName: "td"
					content:
						tagName: "div"
				})
				cell._name = column._name
				row.appendChild(cell)
			contentWrapper = cell.firstChild

			@_refreshFooterCell(contentWrapper, colInfo, isNew)

		while row.lastChild != cell
			row.removeChild(row.lastChild)

		dorado.xRender(row, @_scope)
		if tfoot.rows.length < 1
			tfoot.appendChild(row)
		return

	_refreshFooterCell: (dom, columnInfo, isNew) ->
		column = columnInfo.column

		if column.renderFooter
			if column.renderFooter(dom) != true
				return

		if column.getListeners("renderFooter")
			if column.fire("renderFooter", column, {dom: dom}) == false
				return

		if @getListeners("renderFooter")
			if @fire("renderFooter", @, {column: column, dom: dom}) == false
				return

		if isNew
			template = column._realFooterTemplate
			if template == undefined
				templateName = column._footerTemplate
				if templateName
					template = @_getTemplate(templateName)
				column._realFooterTemplate = template or null
			if template
				template = @_cloneTemplate(template)
				dom.appendChild(template)
		return if column._realFooterTemplate

		dom.innerHTML = "&nbsp;"
		return

	_doRefreshItemDom: (itemDom, item, itemScope) ->
		itemType = itemDom._itemType

		if @getListeners("renderRow")
			if @fire("renderRow", @, {item: item, dom: itemDom}) == false
				return

		if itemType == "default"
			colInfos = @_columnsInfo.dataColumns
			for colInfo, i in colInfos
				column = colInfo.column
				cell = itemDom.cells[i]
				while cell and cell._name != column._name
					itemDom.removeChild(cell)
					cell = itemDom.cells[i]

				if !cell
					isNew = true
					cell = $.xCreate({
						tagName: "td"
						content:
							tagName: "div"
					})
					cell._name = column._name
					itemDom.appendChild(cell)
				contentWrapper = cell.firstChild

				@_refreshCell(contentWrapper, item, colInfo, itemScope, isNew)

			while itemDom.lastChild != cell
				itemDom.removeChild(itemDom.lastChild)
		return

	_refreshCell: (dom, item, columnInfo, itemScope, isNew) ->
		column = columnInfo.column
		dom.style.textAlign = column._align or ""

		if column.renderCell
			if column.renderCell(dom, item, itemScope) != true
				return

		if column.getListeners("renderCell")
			if column.fire("renderCell", column, {item: item, dom: dom, scope: itemScope}) == false
				return

		if @getListeners("renderCell")
			if @fire("renderCell", @,
				{item: item, column: colInfo.column, dom: dom, scope: itemScope}) == false
				return

		if isNew
			template = column._realTemplate
			if template == undefined
				templateName = column._template
				if templateName
					template = @_getTemplate(templateName)
				column._realTemplate = template or null
			if template
				template = @_cloneTemplate(template)
				dom.appendChild(template)
				if columnInfo.property
					context = {
						defaultPath: @_alias + "." + columnInfo.property
					}
				dorado.xRender(dom, itemScope, context)

		return if column._realTemplate

		$dom = $fly(dom)
		if columnInfo.expression
			$dom.attr("d-bind", columnInfo.expression.raw)
		else
			$dom.text(if columnInfo.property then item.get(columnInfo.property) else "")
		return

	_refreshFakeRow: (row) ->
		nextCell = row.firstChild
		for colInfo, i in @_columnsInfo.dataColumns
			cell = nextCell
			if !cell
				cell = $.xCreate({
					tagName: "td"
				})
				row.appendChild(cell)
			else
				nextCell = nextCell.nextSibling

		while nextCell
			cell = nextCell
			nextCell = nextCell.nextSibling
			row.removeChild(cell)
		return

	_getFixedHeader: (create) ->
		fixedHeaderWrapper = @_doms.fixedHeaderWrapper
		if !fixedHeaderWrapper and create
			fixedHeaderWrapper = $.xCreate({
				tagName: "div"
				contextKey: "fixedHeaderWrapper"
				class: "fixed-header table-wrapper"
				content:
					tagName: "table"
					contextKey: "fixedHeaderTable"
			}, @_doms)
			@_dom.appendChild(fixedHeaderWrapper)

			@_doms.fakeThead = fakeThead = $.xCreate(
				tagName: "thead"
				content:
					tagName: "tr"
			)
			@_refreshFakeRow(fakeThead.firstChild)
			$fly(@_doms.tbody).before(fakeThead)
		return fixedHeaderWrapper

	_getFixedFooter: (create) ->
		fixedFooterWrapper = @_doms.fixedFooterWrapper
		if !fixedFooterWrapper and create
			fixedFooterWrapper = $.xCreate({
				tagName: "div"
				contextKey: "fixedFooterWrapper"
				class: "fixed-footer table-wrapper"
				content:
					tagName: "table"
					contextKey: "fixedFooterTable"
			}, @_doms)
			@_dom.appendChild(fixedFooterWrapper, @_doms)

			@_doms.fakeTfoot = fakeTfoot = $.xCreate(
				tagName: "tfoot"
				content:
					tagName: "tr"
			)
			@_refreshFakeRow(fakeTfoot.firstChild)
			$fly(@_doms.tbody).after(fakeTfoot)
		return fixedFooterWrapper

	_refreshFixedColgroup: (colgroup, fixedColgroup) ->
		nextCol = colgroup.firstChild
		nextFixedCol = fixedColgroup.firstChild
		while nextCol
			col = nextCol
			nextCol = nextCol.nextSibling

			fixedCol = nextFixedCol
			if !fixedCol
				fixedCol = document.createElement("col")
			else
				nextFixedCol = nextFixedCol.nextSibling

			fixedCol.width = col.width
			fixedCol.valign = col.valign

		while nextFixedCol
			fixedCol = nextFixedCol
			nextFixedCol = nextFixedCol.nextSibling
			fixedColgroup.removeChild(fixedCol)
		return

	_setFixedHeaderSize: () ->
		colgroup = @_doms.colgroup
		fixedHeaderColgroup = @_doms.fixedHeaderColgroup
		if !fixedHeaderColgroup
			@_doms.fixedHeaderColgroup = fixedHeaderColgroup = colgroup.cloneNode(true)
			@_doms.fixedHeaderTable.appendChild(fixedHeaderColgroup)
		else
			@_refreshFixedColgroup(colgroup, fixedHeaderColgroup)
		$fly(@_doms.fakeThead.firstChild).height(@_doms.thead.offsetHeight)
		return

	_setFixedFooterSize: () ->
		colgroup = @_doms.colgroup
		fixedFooterColgroup = @_doms.fixedFooterColgroup
		if !fixedFooterColgroup
			@_doms.fixedFooterColgroup = fixedFooterColgroup = colgroup.cloneNode(true)
			@_doms.fixedFooterTable.appendChild(fixedFooterColgroup)
		else
			@_refreshFixedColgroup(colgroup, fixedFooterColgroup)
		$fly(@_doms.fakeTfoot.firstChild).height(@_doms.tfoot.offsetHeight)
		return

	_refreshFixedHeader: () ->
		itemsWrapper = @_doms.itemsWrapper
		scrollTop = itemsWrapper.scrollTop
		showFixedHeader = scrollTop > 0
		return if showFixedHeader == @_fixedHeaderVisible

		@_fixedHeaderVisible = showFixedHeader
		if showFixedHeader
			fixedHeader = @_getFixedHeader(true)
			@_setFixedHeaderSize()
			$fly(@_doms.tbody).before(@_doms.fakeThead)
			@_doms.fixedHeaderTable.appendChild(@_doms.thead)
			$fly(fixedHeader).width(itemsWrapper.clientWidth).show()
		else
			fixedHeader = @_getFixedHeader()
			if fixedHeader
				$fly(fixedHeader).hide()
				@_doms.fixedHeaderTable.appendChild(@_doms.fakeThead)
				$fly(@_doms.tbody).before(@_doms.thead)
		return

	_refreshFixedFooter: (duration) ->
		if @_showFooterTimer
			clearInterval(@_showFooterTimer)
			delete @_showFooterTimer

		itemsWrapper = @_doms.itemsWrapper
		scrollTop = itemsWrapper.scrollTop
		maxScrollTop = itemsWrapper.scrollHeight - itemsWrapper.clientHeight
		showFixedFooter = scrollTop < maxScrollTop
		return if showFixedFooter == @_fixedFooterVisible

		@_fixedFooterVisible = showFixedFooter
		if showFixedFooter
			fixedFooter = @_getFixedFooter(true)
			@_setFixedFooterSize()
			$fly(@_doms.tbody).after(@_doms.fakeTfoot)
			@_doms.fixedFooterTable.appendChild(@_doms.tfoot)
			$fixedFooter = $fly(fixedFooter).width(itemsWrapper.clientWidth)
			if duration
				$fixedFooter.fadeIn(duration)
			else
				$fixedFooter.show()
		else
			fixedFooter = @_getFixedFooter()
			if fixedFooter
				$fly(fixedFooter).hide()
				@_doms.fixedFooterTable.appendChild(@_doms.fakeTfoot)
				$fly(@_doms.tbody).after(@_doms.tfoot)
		return

	_onItemsWrapperScroll: () ->
		@_refreshFixedHeader() if @_showHeader
		@_refreshFixedFooter() if @_showFooter
		return