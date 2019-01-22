require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')

class RestoreSpamTicketsTest < ActionView::TestCase
  include ApiTicketsTestHelper
  include UsersHelper
  include ControllerTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @agent = get_admin
    @agent.make_current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_restore_spam_ticket
    user = add_new_user(@account)
    user.deleted_at = Time.now-1.days
    user.save
    ticket = create_ticket(spam: true, requester_id: user.id)
    Tickets::RestoreSpamTicketsWorker.new.perform(user_ids: [user.id])
    ticket.reload
    user.reload
    assert ticket.spam == false
    assert user.deleted_at.nil?
  end

  def test_restore_spam_ticket_with_multiple_user
    user = add_new_user(@account)
    user.deleted_at = Time.now-1.days
    user.save
    ticket = create_ticket(spam: true, requester_id: user.id)

    user1 = add_new_user(@account)
    user1.deleted_at = Time.now-1.days
    user1.save
    ticket1 = create_ticket(spam: true, requester_id: user1.id)

    Tickets::RestoreSpamTicketsWorker.new.perform(user_ids: [user.id, user1.id])
    ticket.reload
    user.reload
    assert ticket.spam == false
    assert user.deleted_at.nil?

    ticket1.reload
    user1.reload
    assert ticket1.spam == false
    assert user1.deleted_at.nil?
  end

  def test_restore_spam_ticket_with_deleted_user
    user = add_new_user(@account)
    user.deleted = true
    user.deleted_at = Time.now-1.days
    user.save
    ticket = create_ticket(spam: true, requester_id: user.id)
    Tickets::RestoreSpamTicketsWorker.new.perform(user_ids: [user.id])
    ticket.reload
    user.reload
    assert ticket.spam == true
    assert user.deleted_at.present?
  end

  def test_restore_spam_ticket_with_exception
    assert_nothing_raised do
      ::Tickets::RestoreSpamTicketsWorker.new.perform({})
    end
  end

  def test_publish_restored_tickets_to_ocr
    @account.stubs(:omni_channel_routing_enabled?).returns(true)
    user = add_new_user(@account)
    user.deleted_at = Time.now-1.days
    user.save
    ticket = create_ticket(spam: true, requester_id: user.id)
    ::OmniChannelRouting::TaskSync.jobs.clear
    Tickets::RestoreSpamTicketsWorker.new.perform(user_ids: [user.id])
    ticket.reload
    user.reload
    assert ticket.spam == false
    assert user.deleted_at.nil?
    assert_equal 1, ::OmniChannelRouting::TaskSync.jobs.size
  ensure
    @account.unstub(:omni_channel_routing_enabled?)
  end

  def test_publish_restored_tickets_to_ocr_with_feature_off
    @account.stubs(:omni_channel_routing_enabled?).returns(false)
    user = add_new_user(@account)
    user.deleted_at = Time.now-1.days
    user.save
    ticket = create_ticket(spam: true, requester_id: user.id)
    ::OmniChannelRouting::TaskSync.jobs.clear
    Tickets::RestoreSpamTicketsWorker.new.perform(user_ids: [user.id])
    ticket.reload
    user.reload
    assert ticket.spam == false
    assert user.deleted_at.nil?
    assert_equal 0, ::OmniChannelRouting::TaskSync.jobs.size
  ensure
    @account.unstub(:omni_channel_routing_enabled?)
  end
end
