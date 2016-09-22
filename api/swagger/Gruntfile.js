module.exports = function(grunt) {

  grunt.initConfig({
    unify: {
      files: ['Gruntfile.js', 'index.yaml', './**/*.yaml', './**/**/*.yaml'],
      options: {
        source: 'index.yaml',
        target: 'swagger.json'
      }
    },
    watch: {
      files: ['<%= unify.files %>'],
      tasks: ['unify']
    }
  });
  
  grunt.registerTask('unify', 'Combine into single Swagger spec file', function () {
    var filenames = this.options();
    var resolve = require('json-refs').resolveRefs;
    var YAML = require('yaml-js');
    var fs = require('fs');

    var root = YAML.load(fs.readFileSync(filenames.source).toString());
    var options = {
      filter        : ['relative', 'remote'],
      loaderOptions : {
        processContent : function (res, callback) {
          callback(null, YAML.load(res.text));
        }
      }
    };
    var done = this.async();
    resolve(root, options).then(function (results) {
      fs.writeFile(filenames.target, JSON.stringify(results.resolved, null, 2), function(err) { 
        if(err) {
            return console.log(err);
        }
        grunt.log.writeln("Unified Swagger file generated");
      });
      done();
    }, function (err) {
      grunt.log.error('Error');
      grunt.log.error(err.stack);
      done(false);
    });
  })
  
  grunt.loadNpmTasks('grunt-contrib-watch');

  grunt.registerTask('default', ['watch']);

};
