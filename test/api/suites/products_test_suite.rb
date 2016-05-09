(Dir['test/api/**/*product*_test.rb'] - Dir['test/api/integration/queries/*product*_test.rb']).each { |file| require "./#{file}" }
