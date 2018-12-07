require_relative  '../../api/unit_test_helper'
require 'faker'
require 'minitest'

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')

class UnicodeSanitizerTest < ActionView::TestCase
  include TicketsTestHelper
  include AccountTestHelper

  def setup
    create_test_account
    create_ticket_with_attachments
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @account.launch(:encode_emoji)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_encode_emoji_happy_path
    ticket = Helpdesk::Ticket.last
    ticket_old_body = ticket.ticket_old_body || ticket.build_ticket_old_body 
    ticket_old_body.attributes = { :description => "Some description goes here 😁"}
    assert_nothing_raised do
      UnicodeSanitizer.encode_emoji(ticket_old_body, "description")
    end
  end

end
