FUNCTIONAL_TESTS_EMBER = Dir.glob('test/api/functional/ember/**/*_test.rb')
FUNCTIONAL_TESTS_PUBLIC = Dir.glob('test/api/functional/**/*_test.rb')
UNIT_TESTS = Dir.glob('test/api/unit/*_test.rb') | Dir.glob('test/api/unit/*/*_test.rb')
PIPE_TESTS = Dir.glob('test/api/**/pipe/**/*_test.rb')
SEARCH_TESTS = Dir.glob('test/api/**/api_search/**/*_test.rb')
FRESHCALLER_CHANNEL_TESTS = Dir.glob('test/api/functional/channel/freshcaller/**/*_test.rb')
INTEGRATION_TESTS = [
    'test/api/integration/flows/private_api_flows_test.rb',
    'test/api/integration/flows/company_fields_flows_test.rb',
    'test/api/integration/flows/contact_fields_flows_test.rb',
    'test/api/integration/flows/ticket_fields_flows_test.rb',
    'test/api/integration/flows/surveys_flows_test.rb',
    'test/api/integration/flows/sla_flow_test.rb'
]
PRESENTER_TESTS = [
  'test/models/presenters/bot/response_test.rb',
  'test/models/presenters/account_test.rb',
  'test/models/presenters/helpdesk/ticket_test.rb'
]
SIDEKIQ_TESTS = Dir.glob('test/api/sidekiq/**/*_test.rb')
SKIP_FILES_SIDEKIQ = Dir.glob('test/api/sidekiq/sandbox/*_test.rb') + Dir.glob('test/api/sidekiq/admin/sla/*_test.rb') + Dir.glob('test/api/sidekiq/community/clear_site_map_test.rb')
SHORYUKEN_TESTS = Dir.glob('test/api/shoryuken/*_test.rb')
SKIP_FILES_FALCON = [
  'test/api/unit/api_throttler_test.rb',
  'test/api/unit/api_solutions/article_validation_test.rb'
]
SKIP_FILES_PUBLIC = ['test/api/functional/shared_ownership_ticket_test.rb']

SUCCESSFUL_SEARCH_TESTS = [
	"test/api/functional/api_search/contacts_controller_test.rb",
	"test/api/functional/api_search/companies_controller_test.rb",
  "test/api/functional/api_search/tickets_controller_test.rb"
]

LIB_TESTS = Dir.glob('test/lib/unit/*_test.rb')
MODEL_TESTS = Dir.glob('test/models/**/*_test.rb')

ALL_TESTS_FALCON = (UNIT_TESTS | FUNCTIONAL_TESTS_EMBER | SIDEKIQ_TESTS | SHORYUKEN_TESTS | INTEGRATION_TESTS | FRESHCALLER_CHANNEL_TESTS | LIB_TESTS | MODEL_TESTS | PRESENTER_TESTS) - SKIP_FILES_FALCON + SUCCESSFUL_SEARCH_TESTS - SKIP_FILES_SIDEKIQ
ALL_TESTS_PUBLIC = (FUNCTIONAL_TESTS_PUBLIC) - FUNCTIONAL_TESTS_EMBER - PIPE_TESTS - SEARCH_TESTS - SKIP_FILES_PUBLIC

ALL_TESTS = (ALL_TESTS_FALCON + ALL_TESTS_PUBLIC).uniq
