Dir['test/core/functional/*_test.rb'].each { |file| require "./#{file}" }
Dir['test/core/functional/**/*_test.rb'].each { |file| require "./#{file}" }