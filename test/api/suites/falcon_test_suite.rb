
# functional
functional_tests = Dir.glob('test/api/functional/ember/**/*_test.rb')

# unit
unit_tests = Dir.glob('test/api/unit/**/*_test.rb')

integration_test = [
  'test/api/integration/flows/private_api_flows_test.rb',
  'test/api/integration/flows/company_fields_flows_test.rb',
  'test/api/integration/flows/contact_fields_flows_test.rb',
  'test/api/integration/flows/ticket_fields_flows_test.rb',
  'test/api/integration/flows/surveys_flows_test.rb'
]

# Files to skip
skip_files = [
  'test/api/unit/api_throttler_test.rb',
  'test/api/unit/api_solutions/article_validation_test.rb'
]
all_tests = (unit_tests | functional_tests | integration_test) - skip_files
puts 'Falcon Test suite - Tests to run'
puts '*' * 100
all_tests.each { |file| puts file }
all_tests.map do |test|
  require "./#{test}"
end
