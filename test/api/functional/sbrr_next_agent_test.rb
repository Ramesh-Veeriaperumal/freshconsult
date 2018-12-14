require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')


class SbrrNextAgentTest < ActiveSupport::TestCase
  include GroupsTestHelper
  include AccountTestHelper
  include ApiTicketsTestHelper

  def setup
    super
    before_all
  end

  def before_all
    if Account.current.nil?
      @user = create_test_account
      @account = @user.account.make_current
      @user.make_current
    else
      @account = Account.current
    end
  end

  #Negative case where count reaches max_retry when no user available in queue
  def test_next_agent_with_no_agent
    assert_nothing_raised do
      SBRR::Queue::User.any_instance.stubs(:top).returns([nil,nil])
      SBRR::Queue::User.any_instance.stubs(:dequeue_object_with_lock).returns(true)
      SBRR::Assigner::User.any_instance.stubs(:no_of_tickets_assigned).returns(0)
      user_id, ticket = sbrr_setup
      t = SBRR::Assigner::User.new ticket
      assigned, next_agent = t.do_assign
      assigned = false if !assigned
      assert_equal false, assigned
    end
  ensure
    unstub_methods
  end

  def test_next_agent_with_no_agent_retry
    assert_nothing_raised do
      user_id, ticket = sbrr_setup
      SBRR::Queue::User.any_instance.stubs(:top).returns([user_id, 100])
      SBRR::Queue::User.any_instance.stubs(:dequeue_object_with_lock).returns(true)
      SBRR::Assigner::User.any_instance.stubs(:no_of_tickets_assigned).returns(6)
      t = SBRR::Assigner::User.new ticket
      assigned, next_agent = t.do_assign
      assigned ||= false
      assert_equal false, assigned
    end
  ensure
    unstub_methods
  end

    #Positive case with selecting 2nd next_agent
  def test_next_agent_with_skip_first_agent
    assert_nothing_raised do
      user_id, ticket = sbrr_setup
      SBRR::Queue::User.any_instance.stubs(:dequeue_object_with_lock).returns(true)
      SBRR::Queue::User.any_instance.stubs(:top).returns([user_id, 100])
      SBRR::Assigner::User.any_instance.stubs(:no_of_tickets_assigned).returns(1).then.returns(0)
      t = SBRR::Assigner::User.new ticket
      assigned, next_agent = t.do_assign
      assert_equal true, assigned
    end
  ensure
    unstub_methods
  end

  #Positive case with selecting next_agent
  def test_next_agent_with_agent
    assert_nothing_raised do
      user_id, ticket = sbrr_setup
      SBRR::Queue::User.any_instance.stubs(:dequeue_object_with_lock).returns(true)
      SBRR::Queue::User.any_instance.stubs(:top).returns([user_id, 100])
      SBRR::Assigner::User.any_instance.stubs(:no_of_tickets_assigned).returns(0)
      t = SBRR::Assigner::User.new ticket
      assigned, next_agent = t.do_assign
      assert_equal true, assigned
    end
  ensure
    unstub_methods
  end

  private

    def unstub_methods
      SBRR::Queue::User.any_instance.unstub(:top)
      SBRR::Queue::User.any_instance.unstub(:dequeue_object_with_lock)
      SBRR::Assigner::User.any_instance.unstub(:no_of_tickets_assigned)
    end
end
