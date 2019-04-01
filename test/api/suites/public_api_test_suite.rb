# functional
falcon_tests = Dir.glob('test/api/functional/ember/**/*_test.rb')

functional_tests = Dir.glob('test/api/functional/**/*_test.rb')

pipe_tests = Dir.glob('test/api/**/pipe/**/*_test.rb')

search_tests = Dir.glob('test/api/**/api_search/**/*_test.rb')

channel_v2_funtional_tests = Dir.glob('test/api/**/channel/v2/*_test.rb')

# unit
unit_tests = Dir.glob('test/api/unit/**/*_test.rb')

channel_tests = Dir.glob('test/api/functional/channel/**/*_test.rb')

channel_v2_tests = Dir.glob('test/api/functional/channel/v2/*_test.rb')

ignore_tests = ['test/api/functional/shared_ownership_ticket_test.rb']
puts "INFRA: #{$infra}"
all_tests = ( functional_tests | unit_tests ) - falcon_tests - pipe_tests - search_tests - 
                                                ignore_tests - channel_v2_tests - 
                                                channel_v2_funtional_tests

puts 'Public API Test suite - Tests to run'
puts '*' * 100
all_tests.each { |file| puts file }
all_tests.map do |test|
  require "./#{test}"
end
