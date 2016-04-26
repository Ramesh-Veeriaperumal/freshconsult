(Dir['test/api/functional/*/*_test.rb'] | Dir['test/api/functional/*_test.rb']).each { |file| require "./#{file}" }
