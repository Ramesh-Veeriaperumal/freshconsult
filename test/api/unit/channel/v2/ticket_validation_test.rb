require_relative '../../../unit_test_helper'
require "#{Rails.root}/test/api/helpers/custom_field_validator_test_helper.rb"
require "#{Rails.root}/test/api/helpers/ticket_fields_test_helper.rb"

module Channel::V2
  class TicketValidationTest < ActionView::TestCase
    include TicketFieldsTestHelper

    DATE_FIELDS = %w(opened_at pending_since resolved_at closed_at first_assigned_at
                  assigned_at first_response_time requester_responded_at agent_responded_at
                  status_updated_at sla_timer_stopped_at).freeze
    INTEGER_FIELDS = %w(avg_response_time_by_bhrs on_state_time resolution_time_by_bhrs 
                      inbound_count outbound_count).freeze
    BOOLEAN_FIELDS = %w(deleted spam group_escalated).freeze
    STATUS_MAPPING = {
      "pending_since" => 3,
      "resolved_at" => 4,
      "closed_at" => 5
    }

    def tear_down
      Account.unstub(:current)
      super
    end

    def statuses
      statuses = []
      (2...7).map do |x|
        h = Helpdesk::TicketStatus.new
        h.status_id = x
        h.stop_sla_timer = true if [3, 4, 5, 6].include?(x)
        statuses << h
      end
      statuses
    end

    def test_create_with_created_at_updated_at
      Account.stubs(:current).returns(Account.first)
      time_now = Time.now
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 2,
                            'created_at' => time_now, 'updated_at' => time_now }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      assert ticket.valid?(:create)
      Account.unstub(:current)
    end

    def test_create_with_required_custom_dropdown_field
      Account.stubs(:current).returns(Account.first)
      @account = Account.current
      create_custom_field_dropdown('test_custom_dropdown', required = true)
      ticket_field = @account.ticket_fields.find_by_name('test_custom_dropdown_1')
      previous_required_field = ticket_field.required
      ticket_field.update_attributes(required: true)
      time_now = Time.now
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 2,
                            'created_at' => time_now, 'updated_at' => time_now }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      assert ticket.valid?(:create)
      ticket_field.update_attributes(required: previous_required_field)
    end

    def test_update_with_required_custom_dropdown_field
      Account.stubs(:current).returns(Account.first)
      @account = Account.current
      create_custom_field_dropdown('test_custom_dropdown', required = true)
      ticket_field = @account.ticket_fields.find_by_name('test_custom_dropdown_1')
      previous_required_field = ticket_field.required
      ticket_field.update_attributes(required: true)
      time_now = Time.now
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 2,
                            'created_at' => time_now, 'updated_at' => time_now }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      assert ticket.valid?(:create)
      ticket_field.update_attributes(required: previous_required_field)
    end

    def test_create_with_required_custom_dependent_field
      Account.stubs(:current).returns(Account.first)
      @account = Account.current
      create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
      ticket_field = @account.ticket_fields.find_by_name('test_custom_country_1')
      previous_required_field = ticket_field.required
      ticket_field.update_attributes(required: true)
      time_now = Time.now
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 2,
                            'created_at' => time_now, 'updated_at' => time_now }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      assert ticket.valid?(:create)
      ticket_field.update_attributes(required: previous_required_field)
    end

    def test_update_with_required_custom_dependent_field
      Account.stubs(:current).returns(Account.first)
      @account = Account.current
      create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
      ticket_field = @account.ticket_fields.find_by_name('test_custom_country_1')
      previous_required_field = ticket_field.required
      ticket_field.update_attributes(required: true)
      time_now = Time.now
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 2,
                            'created_at' => time_now, 'updated_at' => time_now }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      assert ticket.valid?(:update)
      ticket_field.update_attributes(required: previous_required_field)
    end

    def test_created_at_string
      Account.stubs(:current).returns(Account.first)
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 2,
                            'created_at' => 'string', 'updated_at' => Time.now }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      refute ticket.valid?(:create)
      errors = ticket.errors.full_messages
      assert errors.include?('Created at invalid_date')
      Account.unstub(:current)
    end

    def test_created_at_nil
      Account.stubs(:current).returns(Account.first)
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 2,
                            'created_at' => nil, 'updated_at' => Time.now }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      refute ticket.valid?(:create)
      errors = ticket.errors.full_messages
      assert errors.include?('Updated at dependent_timestamp_missing')
      Account.unstub(:current)
    end

    def test_updated_at_nil
      Account.stubs(:current).returns(Account.first)
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 2,
                            'updated_at' => nil, 'created_at' => Time.now }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      refute ticket.valid?(:create)
      errors = ticket.errors.full_messages
      assert errors.include?('Created at dependent_timestamp_missing')
      Account.unstub(:current)
    end

    def test_created_at_and_updated_at_nil
      Account.stubs(:current).returns(Account.first)
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 2,
                            'updated_at' => nil, 'created_at' => nil }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      refute ticket.valid?(:create)
      errors = ticket.errors.full_messages
      assert errors.include?('Created at dependent_timestamp_missing')
      assert errors.include?('Updated at dependent_timestamp_missing')
      Account.unstub(:current)
    end

    def test_created_at_without_updated_at
      Account.stubs(:current).returns(Account.first)
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 2,
                            'created_at' => Time.now }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      refute ticket.valid?(:create)
      errors = ticket.errors.full_messages
      assert errors.include?('Created at dependent_timestamp_missing')
      assert_equal({ description: {}, status: {}, requester_id: {},
                     created_at: { dependent_timestamp: :updated_at, code: :missing_field } }, ticket.error_options)
      Account.unstub(:current)
    end

    def test_updated_at_without_created_at
      Account.stubs(:current).returns(Account.first)
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 2,
                            'updated_at' => Time.now }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      refute ticket.valid?(:create)
      errors = ticket.errors.full_messages
      assert errors.include?('Updated at dependent_timestamp_missing')
      assert_equal({ description: {}, status: {}, requester_id: {},
                     updated_at: { dependent_timestamp: :created_at, code: :missing_field } }, ticket.error_options)
      Account.unstub(:current)
    end

    def test_created_at_gt_current_time
      Account.stubs(:current).returns(Account.first)
      controller_params = { 'requester_id' => 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 2,
                            'created_at' => (Time.now + 10.minutes), 'updated_at' => Time.now }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      refute ticket.valid?(:create)
      errors = ticket.errors.full_messages
      assert errors.include?('Created at start_time_lt_now')
      Account.unstub(:current)
    end

    def test_updated_at_lt_created_at
      Account.stubs(:current).returns(Account.first)
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 2,
                            'created_at' => Time.now, 'updated_at' => (Time.now - 10.minutes) }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      refute ticket.valid?(:create)
      errors = ticket.errors.full_messages
      assert errors.include?('Updated at gt_created_and_now')
      Account.unstub(:current)
    end

    def test_updated_at_gt_current_time
      Account.stubs(:current).returns(Account.first)
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 2,
                            'created_at' => Time.now, 'updated_at' => (Time.now + 10.minutes) }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      refute ticket.valid?(:create)
      errors = ticket.errors.full_messages
      assert errors.include?('Updated at start_time_lt_now')
      Account.unstub(:current)
    end

    def test_create_with_pending_since
      Account.stubs(:current).returns(Account.first)
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 3,
                            pending_since: (Time.now - 5.days),
                            'created_at' => (Time.now - 10.days), 'updated_at' => (Time.now - 10.days) }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      assert ticket.valid?(:create)
      Account.unstub(:current)
    end

    def test_pending_since_nil
      Account.stubs(:current).returns(Account.first)
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 3,
                            pending_since: nil,
                            'created_at' => Time.now, 'updated_at' => Time.now }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      refute ticket.valid?(:create)
      errors = ticket.errors.full_messages
      assert errors.include?('Pending since invalid_date')
      Account.unstub(:current)
    end

    def test_pending_since_lt_current_time
      Account.stubs(:current).returns(Account.first)
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 3,
                            pending_since: (Time.now - 10.minutes),
                            'created_at' => Time.now, 'updated_at' => Time.now }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      refute ticket.valid?(:create)
      errors = ticket.errors.full_messages
      assert errors.include?('Pending since gt_created_and_now')
      Account.unstub(:current)
    end

    def test_pending_since_without_created_at
      Account.stubs(:current).returns(Account.first)
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 3,
                            'pending_since' => Time.now }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      refute ticket.valid?(:create)
      errors = ticket.errors.full_messages
      assert errors.include?('Pending since cannot_set_ticket_state')
      Account.unstub(:current)
    end

    def test_due_by_lt_created_at
      Account.stubs(:current).returns(Account.first)
      current_time = Time.now
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 3,
                            'due_by' => (current_time - 10.minutes), 'fr_due_by' => (current_time - 10.minutes),
                            'created_at' => current_time, 'updated_at' => current_time }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      refute ticket.valid?(:create)
      errors = ticket.errors.full_messages
      assert errors.include?('Due by gt_created_and_now')
      assert errors.include?('Fr due by gt_created_and_now')
      Account.unstub(:current)
    end

    def test_display_id_invalid
      Account.stubs(:current).returns(Account.first)
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 2,
                            display_id: '0' }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      refute ticket.valid?(:create)
      errors = ticket.errors.full_messages
      assert errors.include?('Display datatype_mismatch')
      Account.unstub(:current)
    end

    def test_display_id_integer
      Account.stubs(:current).returns(Account.first)
      display_id = Account.current.tickets.last.display_id + 1
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 2,
                            display_id: display_id }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      assert ticket.valid?(:create)
      Account.unstub(:current)
    end

    DATE_FIELDS.each do |field|
      define_method "test_#{field}_string" do
        Account.stubs(:current).returns(Account.first)
        current_time = Time.now
        status = STATUS_MAPPING[field] || 2
        controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                              ticket_fields: [], statuses: statuses, status: status,
                              field => 'string', 'created_at' => current_time, 
                              'updated_at' => current_time }
        ticket = TicketValidation.new(controller_params, nil)
        refute ticket.valid?(:create)
        errors = ticket.errors.full_messages
        assert errors.first.include?('invalid_date')
        Account.unstub(:current)
      end

      define_method "test_create_with_#{field}" do
        Account.stubs(:current).returns(Account.first)
        start_of_day = Time.now.beginning_of_day
        current_time = Time.now
        status = STATUS_MAPPING[field] || 2
        controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                              ticket_fields: [], statuses: statuses, status: status,
                              field => current_time, 'created_at' => start_of_day, 
                              'updated_at' => start_of_day }
        ticket = TicketValidation.new(controller_params, nil)
        assert ticket.valid?(:create)
        Account.unstub(:current)
      end
    end

    INTEGER_FIELDS.each do |field|
      define_method "test_create_with_#{field}" do
        Account.stubs(:current).returns(Account.first)
        controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                              ticket_fields: [], statuses: statuses, status: 5,
                              field => 100 }
        ticket = TicketValidation.new(controller_params, nil)
        assert ticket.valid?(:create)
        Account.unstub(:current)
      end

      define_method "test_#{field}_invalid" do
        Account.stubs(:current).returns(Account.first)
        controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                              ticket_fields: [], statuses: statuses, status: 2,
                              field => '0' }
        ticket = TicketValidation.new(controller_params, nil)
        refute ticket.valid?(:create)
        errors = ticket.errors.full_messages
        assert errors.first.include?('datatype_mismatch')
        Account.unstub(:current)
      end
    end

    BOOLEAN_FIELDS.each do |field|
      define_method "test_create_with_#{field}" do
        Account.stubs(:current).returns(Account.first)
        controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                              ticket_fields: [], statuses: statuses, status: 5,
                              field => true }
        ticket = TicketValidation.new(controller_params, nil)
        assert ticket.valid?(:create)
        Account.unstub(:current)
      end

      define_method "test_#{field}_invalid" do
        Account.stubs(:current).returns(Account.first)
        controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                              ticket_fields: [], statuses: statuses, status: 2,
                              field => '0' }
        ticket = TicketValidation.new(controller_params, nil)
        refute ticket.valid?(:create)
        errors = ticket.errors.full_messages
        assert errors.first.include?('datatype_mismatch')
        Account.unstub(:current)
      end
    end
  end
end
