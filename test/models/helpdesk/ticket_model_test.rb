require_relative '../test_helper'
['account_helper.rb', 'user_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

class TicketModelTest < ActiveSupport::TestCase
  include AccountHelper
  include UsersHelper
  include TicketsTestHelper
  include EmailHelper

  def setup
    Account.stubs(:current).returns(Account.first || create_test_account)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_should_return_requester_language_if_ticket_has_requester
    @account = Account.current
    user = add_new_user(Account.current, active: true)
    ticket = create_ticket(requester_id: user.id)
    assert_equal ticket.requester_language, user.language
  ensure
    ticket.destroy if ticket.present?
  end

  def test_update_email_received_at_ticket
    time = Time.zone.now.to_s
    parsed_date = parse_internal_date(time)
    ticket = Account.current.tickets.last
    ticket.update_email_received_at(parsed_date)
    assert_equal true, ticket.schema_less_ticket.header_info.key?(:received_at)
  end

  def test_update_email_received_at_blank
    ticket = Account.current.tickets.last
    ticket.update_email_received_at(nil)
    assert_equal false, ticket.schema_less_ticket.header_info.key?(:received_at)
  end
end
