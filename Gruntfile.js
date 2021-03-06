/*
 * grunt-dorado-build
 * https://github.com/AlexTong/grunt-dorado-build
 *
 * Copyright (c) 2015 alextong
 * Licensed under the MIT license.
 */

'use strict';

module.exports = function (grunt) {

	// Project configuration.
	grunt.initConfig({
		jshint: {
			all: [
				'Gruntfile.js',
				'tasks/*.js',
				'<%= nodeunit.tests %>'
			],
			options: {
				jshintrc: '.jshintrc'
			}
		},

		// Before generating any new files, remove any previously-created files.
		clean: {
			tests: ['tmp'],
			build:["resources"],
			doc:["doc"]
		},
		copy: {
			test:{
				expand: true,
				cwd: "/Users/alex/Source/dorado8/trunk/dorado-ui/src",
				src: ["core/**","widget/**"],
				dest: "test/src"
			},
			build: {
				expand: true,
				cwd: "lib",
				src: ["themes/**","doc.css","doc.js"],
				dest: "resources"
			},
			doc: {
				expand: true,
				cwd: "resources",
				src: ["**"],
				dest: "doc/resources"
			}
		},
		concat: {
			"build": {
				files: {
					"resources/3rd.js": [
						"lib/jquery-2.1.3.js",
						"lib/semantic.js",
						"lib/jsbeautify.js",
						"lib/prettify/prettify.js"
					],
					"resources/3rd.css": [
						"lib/semantic.css",
						"lib/grid.css",
						"lib/box.css",
						"lib/prettify/prettify.css"
					]
				}
			},
			dorado: {
				files: {
					"dest/work/dorado.js": ["dest/work/dorado-core.js", "dest/work/dorado-widget.js"]
				}
			}
		},
		yamlToDoc: {
			doc: {
				options: {
					space: 4,
					output:"doc"
				},
				files: [
					{
						expand: true,
						cwd: "test",
						src: ["**/*.yaml", "!i18n/**/*.yaml"],
						dest: "doc"
					}
				]
			}
		},
		// Configuration to be run (and then tested).
		dorado_build: {

			dorado_coffee: {
				options: {},
				files: {
					'tmp/dorado.coffee': ['test/src/base.coffee', 'test/src/element.coffee', 'test/src/keyed-array.coffee', 'test/src/namespace.coffee', 'test/src/util.coffee']
				}
			}
		},

		// Unit tests.
		nodeunit: {
			tests: ['test/*_test.js']
		}

	});

	// Actually load this plugin's task(s).
	grunt.loadTasks('tasks');

	// These plugins provide necessary tasks.
	grunt.loadNpmTasks('grunt-contrib-jshint');
	grunt.loadNpmTasks('grunt-contrib-clean');
	grunt.loadNpmTasks('grunt-contrib-nodeunit');
	grunt.loadNpmTasks("grunt-contrib-copy");
	grunt.loadNpmTasks("grunt-contrib-concat");

	// Whenever the "test" task is run, first clean the "tmp" dir, then run this
	// plugin's task(s), then test the result.
	grunt.registerTask('test', ['clean', 'dorado_build']);

	// By default, lint and run all tests.
	grunt.registerTask('default', ['jshint', 'test']);
	grunt.registerTask('build', ['clean:build', 'copy:build',"concat:build"]);
	grunt.registerTask('doc', ["clean:doc",'yamlToDoc',"copy:build","copy:doc"]);


};
