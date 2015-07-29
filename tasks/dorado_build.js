/*
 * grunt-dorado-build
 * https://github.com/AlexTong/grunt-dorado-build
 *
 * Copyright (c) 2015 alextong
 * Licensed under the MIT license.
 */

'use strict';
var path = require('path'),
	yaml = require('js-yaml'),
	_ = require('lodash'),
	jade = require('jade');
module.exports = function (grunt) {
	var yamlSchema = null;
	var strictOption = false;

	function loadYaml(filepath, options) {
		var data = grunt.file.read(filepath, options);

		try {
			return yaml.safeLoad(data, {
				schema: yamlSchema,
				filename: filepath,
				strict: strictOption
			});
		} catch (e) {
			grunt.warn(e);
			return null;
		}
	}

	function createYamlSchema(customTypes) {
		var yamlTypes = [];

		_.each(customTypes, function (resolver, tagAndKindString) {
			var tagAndKind = tagAndKindString.split(/\s+/);

			var yamlType = new yaml.Type(tagAndKind[0], {
				loadKind: tagAndKind[1],
				loadResolver: function (state) {
					var result = resolver.call(this, state.result, loadYaml);

					if (_.isUndefined(result) || _.isFunction(result)) {
						return false;
					} else {
						state.result = result;
						return true;
					}
				}
			});

			yamlTypes.push(yamlType);
		});

		return yaml.Schema.create(yamlTypes);
	}

	grunt.registerMultiTask('yamlToDoc', 'Compile YAML to JSDOC', function () {
		var options = this.options({
			customTypes: {},
			ignored: null,
			space: 2,
			strict: false,
			readEncoding: grunt.file.defaultEncoding,
			writeEncoding: grunt.file.defaultEncoding
		});


		var readOptions = {
			encoding: options.readEncoding
		};

		var SYMBOLS = {};

		yamlSchema = createYamlSchema(options.customTypes);
		strictOption = options.strict;
		function parseClass(obj) {
			if (obj.stereotype === "namespace") {
				var old = SYMBOLS[obj.name] || {};
				SYMBOLS[obj.name] = _.merge(old, obj, function (a, b) {
					if (_.isArray(a)) {
						return a.concat(b);
					}
				});
			} else {
				SYMBOLS[obj.name] = obj;
			}
		}

		function memberOf(obj, name) {
			var member = obj.name;
			_.each(obj[name], function (item) {
				item.memberOf = member
			});
		}

		function extendHandler(obj, superObj, name) {
			var items = _.union(superObj[name], obj[name]);
			if (name === "methods") {
				_.each(items, function (item) {
					if (!/\)$/.test(item.name)) {
						var argName = "(", args = item.arguments;
						if (args) {
							for (var i = 0; i < args.length; i++) {
								if (i == 0) {
									argName += args[i].name
								} else {
									argName += "," + args[i].name
								}
							}
						}
						argName += ")";
						item.name = item.name + argName;
					}
				})
			}

			if (name === "events") {
				_.each(items, function (item) {
					if (!item.arguments) {
						item.arguments = [
							{
								"name": "self",
								"label": "组件本身"
							},
							{
								"name": "arg"
							}
						];
					} else {
						if (item.arguments.length == 1) {
							var oldArg = item.arguments[0];
							var argName = oldArg.name;
							if (argName == "self") {
								item.arguments = [oldArg, {
									"name": "arg"
								}]
							} else if (argName == "arg") {
								item.arguments = [{
									"name": "self",
									"label": "组件本身"
								}, oldArg]
							}
						}
					}

				})
			}
			obj[name] = _.uniq(items, "name");
		}

		var classDocElements = ["methods", "events", "attributes"];

		_.each(this.files, function (filePair) {
			filePair.src.forEach(function (src) {
				if (grunt.file.isDir(src) || (options.ignored && path.basename(src).match(options.ignored))) {
					return;
				}
				var result = loadYaml(src, readOptions);
				if (_.isArray(result)) {
					_.each(result, function (item) {
						parseClass(item)
					})
				} else if (_.isObject(result)) {
					parseClass(result)
				}
			});
		});

		var aliasNames = [];
		_.each(SYMBOLS, function (alias, name) {
			_.each(classDocElements, function (name) {
				memberOf(alias, name);
			});
			if (alias.stereotype === "class") {
				if (alias.super) {
					var superClass = SYMBOLS[alias.super];
					if (superClass) {
						_.each(classDocElements, function (name) {
							extendHandler(alias, superClass, name)
						});
						_.each(superClass, function (value, key) {
							if (_.indexOf(classDocElements, key) > -1 && !alias[key]) {
								alias[key] = value;
							}
						});
					}
				}
			}

			aliasNames.push(name);
		});
		var dest = path.join(process.cwd(), options.output);
		//grunt.file.write(filePath, JSON.stringify(classMap, null, 4));
		var tamplate = path.join(__dirname, "..", "templates", "doc.jade");

		_.each(SYMBOLS, function (alias, name) {
			var htmlFile = path.join(dest, name + ".html");
			var html = jade.renderFile(tamplate, {title: name, aliasNames: aliasNames, alias: alias});
			grunt.file.write(htmlFile, html);
		});

	});


	grunt.registerMultiTask('dorado-clean', '清除dorado项目中coffee import信息.', function () {
		// 内部使用默认选项定义处
		var options = this.options({
			punctuation: "",
			separator: "",
			importBegin: '#IMPORT_BEGIN',
			importEnd: "#IMPORT_END",
			license: ""
		});
		this.files.forEach(function (f) {
			var src = f.src.filter(function (filepath) {
				if (!grunt.file.exists(filepath)) {
					grunt.log.warn('Source file "' + filepath + '" not found.');
					return false;
				} else {
					return true;
				}
			}).map(function (filepath) {
				var fileDate = grunt.file.read(filepath);
				var reg = new RegExp(options.importBegin + '[\\w\\W\\s\\S]+?' + options.importEnd, "i");

				fileDate = fileDate.replace(reg, "");

				return fileDate;
			}).join(grunt.util.normalizelf(grunt.util.linefeed+options.separator));
			//编写版权信息和结束语
			src = options.license + src + options.punctuation;
			grunt.file.write(f.dest, src);
			grunt.log.writeln('File "' + f.dest + '" created.');
		});
	});

	grunt.registerMultiTask('dorado-license', '为dorado源文件添加版权声明.', function () {
		// 内部使用默认选项定义处
		var options = this.options({
			punctuation: "",
			separator: "",
			license: ""
		});
		this.files.forEach(function (f) {
			var src = f.src.filter(function (filepath) {
				if (!grunt.file.exists(filepath)) {
					grunt.log.warn('Source file "' + filepath + '" not found.');
					return false;
				} else {
					return true;
				}
			}).map(function (filepath) {
				return grunt.file.read(filepath);
			}).join(grunt.util.normalizelf(options.separator));
			//编写版权信息和结束语
			src = options.license + src + options.punctuation;
			grunt.file.write(f.dest, src);
			grunt.log.writeln('File "' + f.dest + '" created.');
		});
	});

};
