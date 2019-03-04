require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'api', 'helpers', 'bot_test_helper.rb')

class CheckTrainingStatusTest < ActionView::TestCase
  include ApiBotTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @bot = @account.main_portal.bot || create_bot({default_avatar: 1})
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_bot_check_training_status_with_inprogress_status
    @bot.training_inprogress!
    ::Admin::BotMailer.stubs(:bot_training_incomplete_email).returns(nil)
    mock = Minitest::Mock.new
    mock.expect(:call, true, ["Bot Training Incomplete :: Account id : #{Account.current.id} :: Bot id : #{@bot.id}"])
    Rails.logger.stub :info, mock do
      Bot::CheckTrainingStatus.new.perform(bot_id: @bot.id)
    end
    mock.verify
  ensure
    ::Admin::BotMailer.unstub(:bot_training_incomplete_email)
  end

  def test_bot_check_training_status_with_completed_status
    @bot.training_completed!
    mock = Minitest::Mock.new
    mock.expect(:call, true, ["Bot Training Completed :: Account id : #{Account.current.id} :: Bot id : #{@bot.id}"])
    Rails.logger.stub :info, mock do
      Bot::CheckTrainingStatus.new.perform(bot_id: @bot.id)
    end
    mock.verify
  end

  def test_bot_check_training_status_with_exception_handled
    assert_nothing_raised do
      @bot.training_inprogress!
      ::Admin::BotMailer.stubs(:bot_training_incomplete_email).raises(RuntimeError)
      Bot::CheckTrainingStatus.new.perform(bot_id: @bot.id)
      ::Admin::BotMailer.unstub(:bot_training_incomplete_email)
    end
  end

end