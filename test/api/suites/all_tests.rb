# integration : flow tests - 'test/api/integration/flows/* : All tests havent been included

# unit
unit_tests = Dir.glob('test/api/unit/**/*_test.rb')

# functional
functional_tests = Dir.glob('test/api/functional/**/*_test.rb')

#integration
integration_test = [
  'test/api/integration/flows/private_api_flows_test.rb',
  'test/api/integration/flows/company_fields_flows_test.rb',
  'test/api/integration/flows/contact_fields_flows_test.rb',
  'test/api/integration/flows/ticket_fields_flows_test.rb',
  'test/api/integration/flows/surveys_flows_test.rb',
  'test/api/integration/flows/action_dispatch_cookies_flows_test.rb'
]
# sidekiq
sidekiq_tests   = Dir.glob('test/api/sidekiq/*_test.rb')


# shoryuken
shoryuken_tests = Dir.glob('test/api/shoryuken/*_test.rb')

# Files to skip
skip_files = [
  'test/api/functional/shared_ownership_ticket_test.rb', 
  'test/api/functional/api_profiles_controller_test.rb'
]

pipe_tests = Dir.glob('test/api/functional/**/pipe/**/*_test.rb')

search_tests = Dir.glob('test/api/**/api_search/**/*_test.rb')

mailer_tests = Dir.glob('test/app/mailers/**/*_test.rb')

all_tests = (unit_tests | functional_tests | sidekiq_tests | shoryuken_tests | integration_test | mailer_tests) - skip_files - pipe_tests - search_tests

puts "INFRA: #{$infra}"

puts 'All Tests - Tests to run'
puts '*' * 100
all_tests.each { |file| puts file }
all_tests.map do |test|
  require "./#{test}"
end
