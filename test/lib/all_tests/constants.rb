FUNCTIONAL_TESTS_EMBER = Dir.glob('test/api/functional/ember/**/*_test.rb')
FUNCTIONAL_TESTS_PUBLIC = Dir.glob('test/api/functional/**/*_test.rb')
OLD_UI_FUNCTIONAL_TESTS = Dir.glob('test/app/controllers/**/*_test.rb')
OLD_UI_INTEGRATION_TESTS = Dir.glob('test/app/integration/flows/**/*_test.rb')
UNIT_TESTS = Dir.glob('test/api/unit/*_test.rb') | Dir.glob('test/api/unit/*/*_test.rb') | Dir.glob('test/api/lib/**/*_test.rb') | Dir.glob('test/lib/solutions/*_test.rb')
PIPE_TESTS = Dir.glob('test/api/**/pipe/**/*_test.rb')
SEARCH_TESTS = Dir.glob('test/api/**/api_search/**/*_test.rb')
API_APP_CONTROLLER_TESTS = Dir.glob('test/api/app/controllers/**/*_test.rb')
FRESHCALLER_CHANNEL_TESTS = Dir.glob('test/api/functional/channel/freshcaller/**/*_test.rb')
INTEGRATION_TESTS = [
  'test/api/integration/flows/private_api_flows_test.rb',
  'test/api/integration/flows/company_fields_flows_test.rb',
  'test/api/integration/flows/contact_fields_flows_test.rb',
  'test/api/integration/flows/ticket_fields_flows_test.rb',
  'test/api/integration/flows/surveys_flows_test.rb',
  'test/api/integration/flows/sla_flow_test.rb',
  'test/api/integration/flows/action_dispatch_cookies_flows_test.rb',
  'test/api/integration/flows/api_search/automations_controller_new_test.rb'
].freeze

WIDGET_PUBLIC_API_FLOW_TESTS = ['test/api/integration/flows/widget_api_flows_test.rb'].freeze

PRESENTER_TESTS = [
  'test/models/presenters/account_test.rb',
  'test/models/presenters/helpdesk/ticket_test.rb',
  'test/models/presenters/group_test.rb',
  'test/models/presenters/agent_test.rb',
  'test/models/presenters/helpdesk/picklist_values_test.rb',
  'test/models/presenters/helpdesk/ticket_status_test.rb',
  'test/models/presenters/custom_survey/survey_handle_test.rb',
  'test/models/presenters/custom_survey/survey_question_choice_test.rb',
  'test/models/presenters/custom_survey/survey_question_test.rb',
  'test/models/presenters/custom_survey/survey_result_test.rb',
  'test/models/presenters/custom_survey/survey_test.rb',
  'test/models/presenters/survey_handle_test.rb',
  'test/models/presenters/survey_result_test.rb',
  'test/models/presenters/survey_test.rb',
  'test/models/presenters/user_test.rb',
  'test/models/presenters/helpdesk/company_test.rb',
  'test/models/presenters/helpdesk/contact_field_test.rb',
  'test/models/presenters/helpdesk/contact_field_choice_test.rb',
  'test/models/presenters/helpdesk/company_field_test.rb',
  'test/models/presenters/helpdesk/company_field_choice_test.rb'

].freeze
SIDEKIQ_TESTS = Dir.glob('test/api/sidekiq/**/*_test.rb')
SKIP_FILES_SIDEKIQ = Dir.glob('test/api/sidekiq/sandbox/*_test.rb') + Dir.glob('test/api/sidekiq/community/clear_site_map_test.rb')
SHORYUKEN_TESTS = Dir.glob('test/api/shoryuken/*_test.rb')
SKIP_FILES_FALCON = [
  'test/api/unit/api_throttler_test.rb',
  'test/api/unit/api_solutions/article_validation_test.rb'
].freeze
SKIP_FILES_PUBLIC = ['test/api/functional/shared_ownership_ticket_test.rb'].freeze

SUCCESSFUL_SEARCH_TESTS = [
  'test/api/functional/api_search/contacts_controller_test.rb',
  'test/api/functional/api_search/companies_controller_test.rb',
  'test/api/functional/api_search/tickets_controller_test.rb',
  'test/api/functional/api_search/autocomplete_controller_test.rb',
  'test/api/functional/api_search/solutions_controller_test.rb'
].freeze


LIB_TESTS = Dir.glob('test/lib/unit/*_test.rb') + Dir.glob('test/lib/unit/**/*_test.rb') + Dir.glob('test/lib/*_test.rb') + Dir.glob('test/lib/helpdesk/**/*_test.rb') + Dir.glob('test/lib/integration_services/**/*_test.rb') + Dir.glob('test/lib/saas/*_test.rb') + Dir.glob('test/lib/spam/*_test.rb') + Dir.glob('test/lib/integrations/**/*_test.rb') + Dir.glob('test/lib/crm/**/*_test.rb') + Dir.glob('test/lib/marketplace/*_test.rb') + Dir.glob('test/lib/reports/*_test.rb') + Dir.glob('test/lib/dashboard/*_test.rb') + Dir.glob('test/lib/email/*_test.rb') + Dir.glob('test/lib/facebook/**/*_test.rb') + Dir.glob('test/lib/redis/*_test.rb') + Dir.glob('test/lib/silkroad/*_test.rb') + Dir.glob('test/lib/channel_integrations/**/*_test.rb') + Dir.glob('test/lib/launch_party/*_test.rb') + Dir.glob('test/lib/dkim/*_test.rb')
MODEL_TESTS = Dir.glob('test/models/**/*_test.rb') + Dir.glob('test/app/models/**/*_test.rb')
MAILER_TESTS = Dir.glob('test/app/mailers/**/*_test.rb')

ALL_TESTS_FALCON = (UNIT_TESTS | FUNCTIONAL_TESTS_EMBER | SIDEKIQ_TESTS | SHORYUKEN_TESTS | INTEGRATION_TESTS | FRESHCALLER_CHANNEL_TESTS | LIB_TESTS | MODEL_TESTS | PRESENTER_TESTS | MAILER_TESTS | API_APP_CONTROLLER_TESTS) - SKIP_FILES_FALCON + SUCCESSFUL_SEARCH_TESTS - SKIP_FILES_SIDEKIQ
ALL_TESTS_PUBLIC = (FUNCTIONAL_TESTS_PUBLIC | OLD_UI_FUNCTIONAL_TESTS | WIDGET_PUBLIC_API_FLOW_TESTS | OLD_UI_INTEGRATION_TESTS) - FUNCTIONAL_TESTS_EMBER - SEARCH_TESTS - SKIP_FILES_PUBLIC

ALL_TESTS = (ALL_TESTS_FALCON + ALL_TESTS_PUBLIC).uniq
