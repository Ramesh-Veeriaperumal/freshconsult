require_relative '../../../unit_test_helper'

module Channel::V2
  class TicketFilterValidationTest < ActionView::TestCase
    def teardown
      Account.unstub(:current)
      super
    end

    def test_presence_of_filter_id
      Account.stubs(:current).returns(Account.first)
      params = {}
      ticket_filter_validation = TicketFilterValidation.new(params, nil)
      refute ticket_filter_validation.valid?
      assert_equal ticket_filter_validation.errors.full_messages.join(' ').include?('filter_id is missing'), true
      Account.unstub(:current)
    end

    def test_numericality_of_filter_id
      Account.stubs(:current).returns(Account.first)
      params = { filter_id: 23 }
      ticket_filter_validation = TicketFilterValidation.new(params, nil)
      assert ticket_filter_validation.valid?
      Account.unstub(:current)
    end

    def test_invalid_filter_id
      Account.stubs(:current).returns(Account.first)
      params = { filter_id: 'apple' }
      ticket_filter_validation = TicketFilterValidation.new(params, nil)
      refute ticket_filter_validation.valid?
      assert_equal ticket_filter_validation.errors.full_messages.join(' ').include?('filter_id should be positive integer'), true
      Account.unstub(:current)
    end
  end
end
