require_relative '../test_helper'
['account_helper.rb', 'user_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

class TicketTest < ActiveSupport::TestCase
  include AccountHelper
  include UsersHelper
  include TicketsTestHelper

  def test_should_return_requester_language_if_ticket_has_requester
    user = add_new_user(Account.current, active: true)
    ticket = create_ticket(requester_id: user.id)
    assert_equal ticket.requester_language, user.language
  ensure
    ticket.destroy
  end
end
