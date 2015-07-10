/*
 * grunt-dorado-build
 * https://github.com/AlexTong/grunt-dorado-build
 *
 * Copyright (c) 2015 alextong
 * Licensed under the MIT license.
 */

'use strict';

module.exports = function (grunt) {
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
