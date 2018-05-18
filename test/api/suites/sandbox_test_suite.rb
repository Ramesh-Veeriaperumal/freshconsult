
controller_tests = Dir.glob('test/api/functional/ember/admin/sandboxes_controller_test.rb')
sidekiq_tests = Dir.glob('test/api/sidekiq/sandbox/*_test.rb')

puts 'Sandbox Controller Test suite - Tests to run'
puts '*' * 100
controller_tests.each { |file| puts file }
controller_tests.map do |test|
  require "./#{test}"
end

puts 'Sandbox Test suite - Tests to run'
puts '*' * 100
sidekiq_tests.each { |file| puts file }
sidekiq_tests.map do |test|
  require "./#{test}"
end
