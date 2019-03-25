require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'api', 'helpers', 'bot_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'create_ticket_helper.rb')

class BotCleanupTest < ActionView::TestCase
  include ApiBotTestHelper
  include CreateTicketHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @bot = @account.main_portal.bot || create_bot({default_avatar: 1})
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_bot_cleanup
    helpdesk_ticket = create_test_ticket(email: 'sample@freshdesk.com')
    create_bot_feedback_and_bot_ticket(helpdesk_ticket, @bot)
    Bot::Cleanup.new.perform(bot_id: @bot.id)
    assert_equal @bot.bot_feedbacks.size, 0
    assert_equal @bot.bot_tickets.size, 0
  end

  def test_bot_cleanup_with_exception_handled
    assert_nothing_raised do
      Account.any_instance.stubs(:bot_tickets).raises(RuntimeError)
      Bot::Cleanup.new.perform(bot_id: @bot.id)
    end
  ensure
    Account.any_instance.unstub(:bot_tickets)
  end

end