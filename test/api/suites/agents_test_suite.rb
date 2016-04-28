(Dir['test/api/**/*agent*_test.rb'] -  Dir['test/api/integration/queries/*agent*_test.rb']).each { |file| require "./#{file}" }
