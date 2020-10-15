require_relative '../unit_test_helper'
require_relative '../../test_transactions_fixtures_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'groups_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'facebook_test_helper.rb')

# Convertion of Facebook Direct messages into tickets/notes

class TrialFacebookWorkerTest < ActionView::TestCase
  include AccountTestHelper
  include GroupsTestHelper
  include FacebookTestHelper

  def teardown
    super
    @account.facebook_pages.destroy_all
    @account.facebook_streams.destroy_all
    @account.tickets.where(source: Helpdesk::Source::FACEBOOK).destroy_all
    Social::FacebookPage.any_instance.unstub(:gateway_facebook_page_mapping_details)
    Account.unstub(:current)
  end

  def setup
    @account = create_test_account
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @fb_page = create_test_facebook_page(@account)
    @user_id = rand(10**10)
    Social::FacebookPage.any_instance.stubs(:gateway_facebook_page_mapping_details).returns(nil)
    before_all
  end

  def before_all
    @fb_page.update_attribute(:message_since, Time.parse((Time.now - 0.5.hour).utc.to_s).to_i)
  end

  def test_record_not_found_exception
    assert_nothing_raised do
      Social::TrialFacebookWorker.any_instance.stubs(:fan_page).raises(ActiveRecord::RecordNotFound)
      thread_id = 9999
      msg_id = thread_id + 20
      time = Time.now.utc
      dm = sample_dms(thread_id, @user_id, msg_id, time)
      Koala::Facebook::API.any_instance.stubs(:get_connections).returns(dm.to_json)
      account_id = Account.last.id + 20
      Social::TrialFacebookWorker.new.perform('account_id' => account_id)
      Social::TrialFacebookWorker.any_instance.unstub(:fan_page)
    end
  end

  def test_dm_is_converted_to_a_ticket
    thread_id = rand(10**10)
    msg_id = thread_id + 20
    time = Time.now.utc
    dm = sample_dms(thread_id, @user_id, msg_id, time)
    Koala::Facebook::API.any_instance.stubs(:get_connections).returns(dm.to_json)
    Social::TrialFacebookWorker.new.perform('account_id' => @account.id)
    Koala::Facebook::API.any_instance.unstub(:get_connections)
    direct_message_data = HashWithIndifferentAccess.new(dm['data'][0])[:messages][:data][0]
    dm_msg_id = direct_message_data[:id]
    ticket = @account.facebook_posts.find_by_post_id(dm_msg_id).postable
    assert_equal ticket.is_a?(Helpdesk::Ticket), true
    assert_equal verify_ticket_properties(ticket, direct_message_data), true
  end

  def test_dm_is_not_converted_to_a_ticket_updated_at
    thread_id = rand(10**10)
    msg_id = thread_id + 20
    time = Time.now.utc
    dm = sample_dms(thread_id, @user_id, msg_id, time)
    Koala::Facebook::API.any_instance.stubs(:get_connections).returns(dm.to_json)
    Social::TrialFacebookWorker.new.perform('account_id' => @account.id)
    Koala::Facebook::API.any_instance.unstub(:get_connections)
    direct_message_data = HashWithIndifferentAccess.new(dm['data'][0])[:messages][:data][0]
    dm_msg_id = direct_message_data[:id]
    ticket = @account.facebook_posts.find_by_post_id(dm_msg_id).postable
    assert_equal ticket.is_a?(Helpdesk::Ticket), true
    assert_equal verify_ticket_properties(ticket, direct_message_data), true
    facebook_post_count = @account.facebook_posts.count
    Timecop.freeze(Time.now.utc - 1.hour) do
      dm = sample_dms(thread_id, @user_id, msg_id, time)
      Koala::Facebook::API.any_instance.stubs(:get_connections).returns(dm.to_json)
      Social::TrialFacebookWorker.new.perform('account_id' => @account.id)
      Koala::Facebook::API.any_instance.unstub(:get_connections)
    end
    assert_equal facebook_post_count, @account.facebook_posts.count
  end

  def test_dm_is_converted_to_a_ticket_with_multiple_mesages
    thread_id = rand(10**10)
    msg_id = thread_id + 20
    time = Time.now.utc
    dm = sample_dms(thread_id, @user_id, msg_id, time)
    dm['data'][0]['messages']['data'].push(
      'id' => (msg_id + 25).to_s,
      'message' => Faker::Lorem.words(10).join(' ').to_s,
      'from' => {
        'name' => Faker::Lorem.words(1).to_s,
        'id' => @user_id.to_s
      },
      'created_time' => time.to_s
    )
    Koala::Facebook::API.any_instance.stubs(:get_connections).returns(dm.to_json)
    Social::TrialFacebookWorker.new.perform('account_id' => @account.id)
    Koala::Facebook::API.any_instance.unstub(:get_connections)
    direct_message_data = HashWithIndifferentAccess.new(dm['data'][0])
    message1 = direct_message_data[:messages][:data][1]
    message2 = direct_message_data[:messages][:data][0]
    dm_msg_id1 = message1[:id]
    dm_msg_id2 = message2[:id]
    ticket = @account.facebook_posts.find_by_post_id(dm_msg_id1).postable
    assert_equal ticket.is_a?(Helpdesk::Ticket), true
    assert_equal verify_ticket_properties(ticket, message1), true
    note = @account.facebook_posts.find_by_post_id(dm_msg_id2).postable
    assert_equal note.is_a?(Helpdesk::Note), true
    assert_equal verify_note_properties(note, message2), true
  end

  def test_dm_is_converted_to_ticket_with_group
    group = create_group(@account)
    rule = @fb_page.dm_stream.ticket_rules[0]
    rule[:action_data][:group_id] = group.id
    rule.save!

    thread_id = rand(10**10)
    msg_id = thread_id + 20
    time = Time.now.utc
    dm = sample_dms(thread_id, @user_id, msg_id, time)
    Koala::Facebook::API.any_instance.stubs(:get_connections).returns(dm.to_json)
    Social::TrialFacebookWorker.new.perform('account_id' => @account.id)
    Koala::Facebook::API.any_instance.unstub(:get_connections)
    dm_msg_id = HashWithIndifferentAccess.new(dm['data'][0])[:messages][:data][0][:id]

    ticket = @account.facebook_posts.find_by_post_id(dm_msg_id).postable
    assert_equal ticket.is_a?(Helpdesk::Ticket), true
    assert_equal ticket.group_id, group.id
  end

  def test_second_dm_after_threading_interval_is_converted_into_a_new_ticket
    @fb_page.update_attributes(dm_thread_time: 3600)

    thread_id = rand(10**10)
    msg_id = thread_id + 20
    time = Time.now.utc

    dm = sample_dms(thread_id, @user_id, msg_id, time)
    Timecop.freeze(Time.now.utc + 1.hour) do
      Koala::Facebook::API.any_instance.stubs(:get_connections).returns(dm.to_json)
      Social::TrialFacebookWorker.new.perform('account_id' => @account.id)
    end
    Koala::Facebook::API.any_instance.unstub(:get_connections)
    first_msg_id = HashWithIndifferentAccess.new(dm['data'][0])[:messages][:data][0][:id]
    second_msg_id = HashWithIndifferentAccess.new(dm['data'][1])[:messages][:data][0][:id]
    assert_equal @account.facebook_posts.find_by_post_id(first_msg_id).postable.is_a?(Helpdesk::Ticket), true
    assert_equal @account.facebook_posts.find_by_post_id(second_msg_id).postable.is_a?(Helpdesk::Ticket), true
  end

  def test_second_dm_within_threading_interval_is_added_as_a_note_on_same_ticket
    thread_id = rand(10**10)
    msg_id = thread_id + 20
    time = Time.now.utc

    dm = sample_dms(thread_id, @user_id, msg_id, time)
    Koala::Facebook::API.any_instance.stubs(:get_connections).returns(dm.to_json)
    Social::TrialFacebookWorker.new.perform('account_id' => @account.id)
    Koala::Facebook::API.any_instance.unstub(:get_connections)
    first_msg_id = HashWithIndifferentAccess.new(dm['data'][0])[:messages][:data][0][:id]
    second_msg_data = HashWithIndifferentAccess.new(dm['data'][1])[:messages][:data][0]
    second_msg_id = second_msg_data[:id]
    assert_equal @account.facebook_posts.find_by_post_id(first_msg_id).postable.is_a?(Helpdesk::Ticket), true
    note = @account.facebook_posts.find_by_post_id(second_msg_id).postable
    assert_equal note.is_a?(Helpdesk::Note), true

    verify_note_properties(note, second_msg_data)
  end

  def test_multiple_dm_messages_within_thread_interval_to_notes_on_same_ticket
    thread_id = rand(10**10)
    Timecop.travel(1.second)
    create_facebook_dm_as_ticket(@fb_page, thread_id, @user_id)
    next_msg_id = rand(10**10)
    time = (Time.now + 1.hour).utc
    next_msgs = sample_dms(thread_id, @user_id, next_msg_id, time)
    Koala::Facebook::API.any_instance.stubs(:get_connections).returns(next_msgs.to_json)
    Social::TrialFacebookWorker.new.perform('account_id' => @account.id)
    Koala::Facebook::API.any_instance.unstub(:get_connections)
    first_msg_id = HashWithIndifferentAccess.new(next_msgs['data'][0])[:messages][:data][0][:id]
    second_msg_id = HashWithIndifferentAccess.new(next_msgs['data'][1])[:messages][:data][0][:id]
    fb_posts = @account.facebook_posts
    assert_equal fb_posts.find_by_post_id(first_msg_id).postable.is_a?(Helpdesk::Note), true
    assert_equal fb_posts.find_by_post_id(second_msg_id).postable.is_a?(Helpdesk::Note), true
  end

  def test_do_not_convert_dm_by_worker_when_realtime_messaging_is_enabled
    @fb_page.update_attributes(realtime_messaging: true)

    thread_id = rand(10**10)
    msg_id = thread_id + 20
    time = Time.now.utc
    dm = sample_dms(thread_id, @user_id, msg_id, time)
    Koala::Facebook::API.any_instance.stubs(:get_connections).returns(dm.to_json)
    Social::TrialFacebookWorker.new.perform('account_id' => @account.id)
    Koala::Facebook::API.any_instance.unstub(:get_connections)
    direct_message_data = HashWithIndifferentAccess.new(dm['data'][0])['messages']['data'][0]
    dm_msg_id = direct_message_data['id']
    assert_nil @account.facebook_posts.find_by_post_id(dm_msg_id)
  end

  def test_do_not_convert_dm_when_import_dms_is_not_choosen
    @fb_page.update_attributes(import_dms: false)

    thread_id = rand(10**10)
    msg_id = thread_id + 20
    time = Time.now.utc
    dm = sample_dms(thread_id, @user_id, msg_id, time)
    Koala::Facebook::API.any_instance.stubs(:get_connections).returns(dm.to_json)
    Social::TrialFacebookWorker.new.perform('account_id' => @account.id)
    Koala::Facebook::API.any_instance.unstub(:get_connections)
    direct_message_data = HashWithIndifferentAccess.new(dm['data'][0])['messages']['data'][0]
    dm_msg_id = direct_message_data['id']
    assert_nil @account.facebook_posts.find_by_post_id(dm_msg_id)
  end

  def test_post_is_converted_to_ticket
    @fb_page.update_attributes(import_visitor_posts: true, message_since: nil)

    sender_id = rand(10**10)
    feed_id = rand(10**15)
    time = Time.now.utc
    feed = sample_post_feed(@fb_page.page_id, sender_id, feed_id, time)

    Koala::Facebook::API.any_instance.stubs(:get_connections).returns(feed)
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(feed[0])
    Social::TrialFacebookWorker.new.perform('account_id' => @account.id)
    Koala::Facebook::API.any_instance.unstub(:get_connections)
    Koala::Facebook::API.any_instance.unstub(:get_object)
    @account.reload
    post_id = feed[0][:id]
    assert_equal @account.facebook_posts.find_by_post_id(post_id).postable.is_a?(Helpdesk::Ticket), true
    ticket = @account.facebook_posts.find_by_post_id(post_id).postable
    assert_equal ticket.source, 6
    assert_equal ticket.requester.fb_profile_id, feed[0][:from]['id']
    assert_equal ticket.description, feed[0][:message]
  end
end
