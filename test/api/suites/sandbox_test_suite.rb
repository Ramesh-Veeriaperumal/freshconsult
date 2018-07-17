
sidekiq_tests = Dir.glob('test/api/sidekiq/sandbox/*_test.rb')

puts 'Sandbox Controller Test suite - Tests to run'
puts '*' * 100
puts 'Sandbox Test suite - Tests to run'
puts '*' * 100
sidekiq_tests.each { |file| puts file }
sidekiq_tests.map do |test|
  require "./#{test}"
end
