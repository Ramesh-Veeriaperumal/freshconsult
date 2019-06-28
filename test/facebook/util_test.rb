require_relative '../test_helper'
require Rails.root.join('spec', 'support', 'account_helper.rb')
class UtilTest < ActionView::TestCase
  include AccountHelper
  include Facebook
  include TicketActions
  include DirectMessage
  include Util

  def setup
    super
    before_all
  end

  @before_all_run = false

  def before_all
    return if @before_all_run
    @account = create_test_account
    @before_all_run = true
  end

  def teardown
    super
  end

  def test_error_html_content_from_message
    @fan_page = Portal::Page.new(account_id: 1)
    UtilTest.any_instance.stubs(:facebook_user).returns(User.first)
    UtilTest.any_instance.stubs(:filter_messages_from_data_set).returns([{ created_time: Time.current.to_s, from: User.first, shares: { data: [{ link: 'https://www.facebook.com/\u{421}\u{435}-\u{410}\u{430}-\u{434}\u{430}\u{43d}\u{438}\u{442}\u{435}-453705798422201/' }] } }])
    resp = add_as_note(Thread.current, Account.current.tickets.first)
  ensure
    UtilTest.any_instance.unstub(:facebook_user)
    UtilTest.any_instance.unstub(:filter_messages_from_data_set)
  end
end
