(Dir['test/api/**/*group*_test.rb'] - Dir['test/api/integration/queries/*group*_test.rb']).each { |file| require "./#{file}" }
