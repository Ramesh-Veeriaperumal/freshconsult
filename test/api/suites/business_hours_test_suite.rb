(Dir['test/api/**/*business_hour*_test.rb'] - Dir['test/api/integration/queries/*business_hour*_test.rb']).each { |file| require "./#{file}" }
