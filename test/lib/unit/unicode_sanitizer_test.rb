require_relative  '../../api/unit_test_helper'
require 'faker'
require 'minitest'
require_relative '../../core/helpers/users_test_helper'

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')

class UnicodeSanitizerTest < ActionView::TestCase
  include CoreTicketsTestHelper
  include AccountTestHelper
  include CoreUsersTestHelper

  def setup
    create_test_account
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @account.launch(:encode_emoji)
    create_ticket_with_attachments
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_encode_emoji_happy_path
    ticket = Helpdesk::Ticket.last
    ticket_body = ticket.ticket_body || ticket.build_ticket_body 
    ticket_body.attributes = { :description => "Some description goes here 😁"}
    assert_nothing_raised do
      UnicodeSanitizer.encode_emoji(ticket_body, "description")
    end
  end

end
