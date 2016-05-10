# functional
require_relative '../functional/tickets_controller_test.rb'
require_relative '../functional/api_application_controller_test.rb'
require_relative '../functional/api_ticket_fields_controller_test.rb'
require_relative '../functional/conversations_controller_test.rb'
require_relative '../functional/ticket_concern_test.rb'
require_relative '../functional/time_entries_controller_test.rb'

# unit
require_relative '../unit/ticket_validation_test.rb'
require_relative '../unit/ticket_filter_validation_test.rb'
require_relative '../unit/conversation_validation_test.rb'
require_relative '../unit/tickets_dependency_test.rb'
require_relative '../unit/time_entries_dependency_test.rb'
require_relative '../unit/time_entry_validation_test.rb'
require_relative '../unit/time_entry_filter_validation_test.rb'

# flows
require_relative '../integration/flows/conversations_flow_test.rb'
require_relative '../integration/flows/tickets_flow_test.rb'
require_relative '../integration/flows/time_entries_flow_test.rb'

# queries
# require_relative 'integration/queries/conversations_queries_test.rb'
# require_relative 'integration/queries/tickets_queries_test.rb'
# require_relative 'integration/queries/time_entries_queries_test.rb'
# require_relative 'integration/queries/ticket_fields_queries_test.rb'
