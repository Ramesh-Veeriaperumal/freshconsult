module.exports = function(grunt) {

  grunt.initConfig({
    unify: {
      all: {
        options: {
          source: 'index.yaml',
          target: 'swagger.json'
        }
      },
      help_widget: {
        options: {
          source: 'help_widget/index.yaml',
          target: 'help_widget/swagger.json'
        }
      }
    },
    watch: {
      files: ['Gruntfile.js', 'index.yaml', 'help_widget/index.yaml', './**/*.yaml', './**/**/*.yaml'],
      tasks: ['unify']
    }
  });

  grunt.registerMultiTask('unify', 'Combine into single Swagger spec file', function() {
    var filenames = this.options();
    var task = this.nameArgs;
    var resolve = require('json-refs').resolveRefs;
    var YAML = require('yaml-js');
    var fs = require('fs');
    var swaggerParser = require('swagger-parser');

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
        grunt.log.writeln("Unified Swagger file generated for " + task);
        swaggerParser.validate(filenames.target, function(err, api) {
          if (err) {
            grunt.log.error(filenames.target + ' Validation Error:');
            grunt.log.error(err.stack);
            done(false);
          }
          else {
            done();
          }
        });
      });
    }, function (err) {
      grunt.log.error('Error');
      grunt.log.error(err.stack);
      done(false);
    });
  })
  
  grunt.loadNpmTasks('grunt-contrib-watch');

  grunt.registerTask('default', ['watch']);

};
