require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'discussions_test_helper.rb')

class DeactivateMonitorshipTest < ActionView::TestCase
  include AccountTestHelper
  include DiscussionsTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @topic = Topic.first || create_test_topic(Forum.first)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_deactivate_monitorship
    user = create_dummy_customer
    monitor_topic(@topic, user, @account.main_portal.id)
    Community::DeactivateMonitorship.new.perform(user.id)
    assert_equal user.monitorships.active_monitors.size, 0
  end

  def test_deactivate_monitorship_with_invalid_user
    user = User.last || create_dummy_customer
    monitor_topic(@topic, user, @account.main_portal.id)
    monitorship_count = user.monitorships.active_monitors.size
    mock = Minitest::Mock.new
    mock.expect(:call, true, ["DeactivateMonitorship: account #{Account.current.id} - User not found #{user.id+20}"])
    Rails.logger.stub :info, mock do
      Community::DeactivateMonitorship.new.perform(user.id+20)
    end
    mock.verify
    assert_equal user.monitorships.active_monitors.size, monitorship_count
  end

  def test_deactivate_monitorship_with_exception_handled
    assert_nothing_raised do
      user = create_dummy_customer
      User.any_instance.stubs(:monitorships).raises(RuntimeError)
      Community::DeactivateMonitorship.new.perform(user.id)
    end
  ensure
    User.any_instance.unstub(:monitorships)
  end
end