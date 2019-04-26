require_relative '../../unit_test_helper'
require_relative '../../../lib/helpers/contact_segments_test_helper.rb'
require_relative '../../../core/helpers/tickets_test_helper.rb'
require_relative '../../helpers/forums_test_helper.rb'
require_relative '../../../core/helpers/forums_test_helper.rb'
require_relative '../../../core/helpers/account_test_helper.rb'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

class ContactDeleteForeverWorkerTest < ActionView::TestCase
  include AccountTestHelper
  include ContactSegmentsTestHelper
  include CoreTicketsTestHelper
  include CoreForumsTestHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def setup
    create_test_account if Account.first.nil?
    @account = Account.first
    Account.stubs(:current).returns(@account)
    Account.current.launch(:contact_delete_forever)
    Users::ContactDeleteForeverWorker.clear
  end

  def teardown
    Account.current.rollback(:contact_delete_forever)
    User.reset_current_user
    Account.unstub(:current)
    super
  end

  def construct_args(usr_id)
    {
      'user_id' => usr_id
    }
  end

  def test_contact_delete_worker_runs
    usr = create_contact(deleted: true)
    args = construct_args(usr.id)
    Users::ContactDeleteForeverWorker.new.perform(args)
    assert_equal 0, ::Users::ContactDeleteForeverWorker.jobs.size
  end

  def test_contact_delete_worker_runs_with_delay
    usr = create_contact(deleted: true)
    usr.delete_forever!
    assert_equal 1, ::Users::ContactDeleteForeverWorker.jobs.size
  end

  def test_contact_gets_deleted_by_worker
    usr = create_contact(deleted: true)
    args = construct_args(usr.id)
    old_length = Account.current.all_contacts.where(deleted: true).length
    Users::ContactDeleteForeverWorker.new.perform(args)
    Account.current.reload
    new_length = Account.current.all_contacts.where(deleted: true).length
    assert_equal 0, ::Users::ContactDeleteForeverWorker.jobs.size
    assert_equal old_length - 1, new_length
  end

  def test_worker_gets_reenqueued_if_redis_check
    usr = create_contact(deleted: true)
    args = construct_args(usr.id)
    Users::ContactDeleteForeverWorker.any_instance.stubs(:get_others_redis_key).returns(2)
    Users::ContactDeleteForeverWorker.new.perform(args)
    assert_equal 1, ::Users::ContactDeleteForeverWorker.jobs.size
    Users::ContactDeleteForeverWorker.clear
  end

  def test_contact_which_was_agent_gets_anonymized
    usr = create_contact(deleted: true)
    args = construct_args(usr.id)
    User.any_instance.stubs(:was_agent?).returns(true)
    Users::ContactDeleteForeverWorker.new.perform(args)
    usr.reload
    assert_equal usr.email, nil
    assert_equal usr.name, 'Deleted Agent'
    assert_equal usr.preferences[:user_preferences][:agent_deleted_forever], true
    assert_equal 0, ::Users::ContactDeleteForeverWorker.jobs.size
  end

  def test_tickets_created_by_contact_gets_deleted
    usr = create_contact(deleted: true)
    ticket = create_ticket(requester_id: usr.id)
    args = construct_args(usr.id)
    Users::ContactDeleteForeverWorker.new.perform(args)
    assert_equal 0, Account.current.tickets.where(requester_id: usr.id).length
    assert_equal 0, ::Users::ContactDeleteForeverWorker.jobs.size
  end

  def test_posts_created_by_contact_gets_deleted
    usr = create_contact(deleted: true)
    args = construct_args(usr.id)
    create_test_topic(create_test_forum(create_test_category), usr)
    Users::ContactDeleteForeverWorker.new.perform(args)
    assert_equal 0, Account.current.posts.where(user_id: usr.id).length
    assert_equal 0, ::Users::ContactDeleteForeverWorker.jobs.size
  end

  def test_child_tickets_get_deleted_and_disassociated
    usr = create_contact(deleted: true)
    args = construct_args(usr.id)
    @agent = usr
    Account.current.add_feature(:parent_child_tickets)
    prt_ticket = create_parent_ticket(requester_id: usr.id)
    prt_ticket.spam = false
    prt_ticket.association_type = 1
    prt_ticket.save
    options = {:requester_id => @agent.id, :assoc_parent_id => prt_ticket.display_id, :subject => "#{params[:subject]}_child_tkt"}
    child_tkt = create_ticket(options)
    child_tkt.spam = false
    child_tkt.parent_ticket_id = prt_ticket.display_id
    child_tkt.save
    Users::ContactDeleteForeverWorker.new.perform(args)
    Account.current.revoke_feature(:parent_child_tickets)
    assert_equal 0, Account.current.tickets.where(requester_id: usr.id).length
    assert_equal 0, ::Users::ContactDeleteForeverWorker.jobs.size
  end

  def test_unpublished_spam_gets_deleted
    posts = []
    usr = create_contact(deleted: true)
    args = construct_args(usr.id)
    create_test_topic(create_test_forum(create_test_category), usr)
    posts.push(Account.current.posts.last)
    ::ForumSpam.stubs(:by_user).returns(posts)
    ::ForumUnpublished.stubs(:by_user).returns(posts)
    ::Post.any_instance.stubs(:user_timestamp).returns(nil)
    ::Post.any_instance.stubs(:destroy_attachments).returns(true)
    Users::ContactDeleteForeverWorker.new.perform(args)
    assert_equal 0, Account.current.posts.where(user_id: usr.id).length
    assert_equal 0, ::Users::ContactDeleteForeverWorker.jobs.size
  end

  def test_worker_gets_reenqueued_if_redis_check_and_min_max_gets_reset
    usr = create_contact(deleted: true)
    args = construct_args(usr.id)
    Users::ContactDeleteForeverWorker.any_instance.stubs(:get_others_redis_key).returns(2)
    Users::ContactDeleteForeverWorker.any_instance.stubs(:check_min_and_max_time).returns(true)
    Users::ContactDeleteForeverWorker.new.perform(args)
    assert_equal 1, ::Users::ContactDeleteForeverWorker.jobs.size
    Users::ContactDeleteForeverWorker.clear
  end

  def test_worker_errors_out_on_exception
    args = {}
    Users::ContactDeleteForeverWorker.any_instance.stubs(:get_others_redis_key).returns(2)
    Users::ContactDeleteForeverWorker.stubs(:perform_in).raises(StandardError)
    Users::ContactDeleteForeverWorker.new.perform(args)
    assert_equal 0, ::Users::ContactDeleteForeverWorker.jobs.size
  rescue Exception => e
  ensure
    Users::ContactDeleteForeverWorker.clear
  end
end
