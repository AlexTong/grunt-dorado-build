$(".menu .item").tab();
var jsBeautifyOptions = {
	space_before_conditional: true,
	keep_array_indentation: false,
	preserve_newlines: true,
	unescape_strings: true,
	jslint_happy: false,
	brace_style: "end-expand",
	indent_char: " ",
	indent_size: 4
};
$(".description>code").each(function () {
	var $dom = $(this);
	var html = $dom.html();
	$dom.addClass("prettyprint")
	var pre = document.createElement("pre");
	//var $pre = $(pre);
	var code = js_beautify(html.toString(), jsBeautifyOptions);
	//$pre.text(code)
	$dom.text(code)

});
prettyPrint();