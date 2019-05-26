require_relative '../unit_test_helper'
require_relative '../../test_transactions_fixtures_helper'
require "#{Rails.root}/test/api/helpers/custom_field_validator_test_helper.rb"

class FsmTicketValidationTest < ActionView::TestCase
	include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
	include ::Admin::AdvancedTicketing::FieldServiceManagement::Constant

	def setup
		Account.stubs(:current).returns(Account.first)
		perform_fsm_operations
		Account.reset_current_account
    Account.stubs(:current).returns(Account.first)
		ticket_fields = Account.current.ticket_fields_from_cache
		@params_hash = { requester_id: 1, description: Faker::Lorem.paragraph,  ticket_fields: [], subject: Faker::Lorem.characters(10),ticket_type: SERVICE_TASK_TYPE, priority: 1, statuses: statuses, status: 2, ticket_fields: ticket_fields   }
	end

	def teardown
		cleanup_fsm
		Account.unstub(:current)
	end

	def statuses
		statuses  = []
		(2...7).map do |x|
			h = Helpdesk::TicketStatus.new
			h.status_id = x
			h.stop_sla_timer = true if [3, 4, 5, 6].include?(x)
			statuses << h
		end
		statuses
	end

	def test_create_ticket_with_type_service_task_invalid
		@ticket_fields = Account.current.ticket_fields_from_cache
		controller_params = @params_hash
		ticket = FsmTicketValidation.new(controller_params, nil)
		refute ticket.valid?(:create)
		errors = ticket.errors.full_messages
		assert errors.include?("Cf fsm contact name 1 datatype_mismatch")
		assert errors.include?("Cf fsm phone number 1 datatype_mismatch")
		assert errors.include?("Cf fsm service location 1 datatype_mismatch")
	end

	def test_create_ticket_with_type_service_task_valid
		@ticket_fields = Account.current.ticket_fields_from_cache
		controller_params = @params_hash.merge( custom_fields: {cf_fsm_contact_name_1: Faker::Lorem.characters(10),cf_fsm_service_location_1: Faker::Lorem.characters(10), cf_fsm_phone_number_1: Faker::Lorem.characters(10)})
		ticket = FsmTicketValidation.new(controller_params, nil)
		assert ticket.valid?(:create)
	end

	def test_update_ticket_with_type_service_task_invalid
		@ticket_fields = Account.current.ticket_fields_from_cache
		controller_params = @params_hash
		ticket = FsmTicketValidation.new(controller_params, nil)
		refute ticket.valid?(:update)
		errors = ticket.errors.full_messages
		assert errors.include?("Cf fsm contact name 1 datatype_mismatch")
		assert errors.include?("Cf fsm phone number 1 datatype_mismatch")
		assert errors.include?("Cf fsm service location 1 datatype_mismatch")
	end

	def test_update_ticket_with_type_service_task_valid
		@ticket_fields = Account.current.ticket_fields_from_cache
		controller_params = @params_hash.merge(custom_fields: {cf_fsm_contact_name_1: Faker::Lorem.characters(10),cf_fsm_service_location_1: Faker::Lorem.characters(10), cf_fsm_phone_number_1:Faker::Lorem.characters(10)})
		ticket = FsmTicketValidation.new(controller_params, nil)
		assert ticket.valid?(:update)
	end

	def test_other_custom_fields_when_creating_ticket_type_service_task
		CustomFieldValidatorTestHelper.new(account_id: Account.current.id, name: 'second_1', label: 'second', label_in_portal: 'second', description: nil, active: true, field_type: 'nested_field', position: 22, required: true, visible_in_portal: false, editable_in_portal: false, required_in_portal: false, required_for_closure: false, flexifield_def_entry_id: 4, prefered_ff_col: nil, import_id: nil)
		@ticket_fields = Account.current.ticket_fields_from_cache
		controller_params = @params_hash.merge( custom_fields: {cf_fsm_contact_name_1: Faker::Lorem.characters(10),cf_fsm_service_location_1: Faker::Lorem.characters(10), cf_fsm_phone_number_1: Faker::Lorem.characters(10)})
		ticket = FsmTicketValidation.new(controller_params, nil)
		assert ticket.valid?(:create)
	end

	def test_other_require_for_closure_custom_fields_when_creating_ticket_type_service_task_passes
		CustomFieldValidatorTestHelper.new(account_id: Account.current.id, name: 'second_2', label: 'second', label_in_portal: 'second', description: nil, active: true, field_type: 'nested_field', position: 23, required: false, visible_in_portal: false, editable_in_portal: false, required_in_portal: false, required_for_closure: true, flexifield_def_entry_id: 4, prefered_ff_col: nil, import_id: nil)
		@ticket_fields = Account.current.ticket_fields_from_cache
		controller_params = @params_hash.merge({status: 5, custom_fields: {cf_fsm_contact_name_1: Faker::Lorem.characters(10),cf_fsm_service_location_1: Faker::Lorem.characters(10), cf_fsm_phone_number_1: Faker::Lorem.characters(10)}})
		ticket = FsmTicketValidation.new(controller_params, nil)
		assert ticket.valid?(:update)
	end
end