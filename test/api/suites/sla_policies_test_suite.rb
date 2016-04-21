(Dir['test/api/**/*sla*_test.rb'] - Dir['test/api/integration/queries/*sla*_test.rb']).each { |file| require "./#{file}" }
