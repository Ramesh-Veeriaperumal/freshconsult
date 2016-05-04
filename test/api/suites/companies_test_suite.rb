(Dir['test/api/**/*compan*_test.rb'] - Dir['test/api/integration/queries/*compan*_test.rb']).each { |file| require "./#{file}" }
