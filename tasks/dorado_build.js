/*
 * grunt-dorado-build
 * https://github.com/AlexTong/grunt-dorado-build
 *
 * Copyright (c) 2015 alextong
 * Licensed under the MIT license.
 */

'use strict';

module.exports = function (grunt) {

	grunt.registerMultiTask('dorado_build', 'Dorado Ui Build.', function () {
		// 内部使用默认选项定义处
		var options = this.options({
			punctuation: "\n#上海锐道信息技术有限公司版权所有",
			separator: "",
			importBegin: '#IMPORT_BEGIN',
			importEnd: "#IMPORT_END",
			license: "#www.dorado.io"
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
				//var reg=/#IMPORT_BEGIN[\w\W\s\S]+?#IMPORT_END/i;
				var reg = new RegExp(options.importBegin + '[\\w\\W\\s\\S]+?' + options.importEnd, "i");

				fileDate = fileDate.replace(reg, "")

				return fileDate;
			}).join(grunt.util.normalizelf(options.separator));
			//编写版权信息和结束语
			src = options.license + src + options.punctuation;
			grunt.file.write(f.dest, src);
			grunt.log.writeln('File "' + f.dest + '" created.');
		});
	});

};
