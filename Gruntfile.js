/*
 * grunt-dorado-build
 * https://github.com/AlexTong/grunt-dorado-build
 *
 * Copyright (c) 2015 alextong
 * Licensed under the MIT license.
 */

'use strict';

module.exports = function(grunt) {

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
      tests: ['tmp']
    },

    // Configuration to be run (and then tested).
    dorado_build: {

      dorado_coffee:{
        options: {
        },
        files: {
          'tmp/dorado.coffee': ['test/src/base.coffee', 'test/src/element.coffee','test/src/keyed-array.coffee','test/src/namespace.coffee','test/src/util.coffee']
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

  // Whenever the "test" task is run, first clean the "tmp" dir, then run this
  // plugin's task(s), then test the result.
  grunt.registerTask('test', ['clean', 'dorado_build']);

  // By default, lint and run all tests.
  grunt.registerTask('default', ['jshint', 'test']);

};
