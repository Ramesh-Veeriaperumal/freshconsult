(Dir['test/api/**/*contact*_test.rb'] -  Dir['test/api/integration/queries/*contact*_test.rb']).each { |file| require "./#{file}" }
