require_relative '../../unit_test_helper'
require "#{Rails.root}/test/api/helpers/custom_field_validator_test_helper.rb"

module Pipe
  class TicketValidationTest < ActionView::TestCase
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

    def test_pending_since_without_pending_status
      Account.stubs(:current).returns(Account.first)
      current_time = Time.now
      controller_params = { requester_id: 1, description: Faker::Lorem.paragraph,
                            ticket_fields: [], statuses: statuses, status: 2,
                            'pending_since' => current_time,
                            'created_at' => current_time, 'updated_at' => current_time }
      item = nil
      ticket = TicketValidation.new(controller_params, item)
      refute ticket.valid?(:create)
      errors = ticket.errors.full_messages
      assert errors.include?('Pending since cannot_set_pending_since')
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
      assert errors.include?('Pending since cannot_set_pending_since')
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
  end
end
