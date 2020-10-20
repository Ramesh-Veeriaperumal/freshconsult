require_relative '../unit_test_helper'
require_relative '../../test_transactions_fixtures_helper'

require Rails.root.join('test', 'api', 'helpers', 'facebook_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'groups_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

# Test cases for facebook real time messaging in facebook
class FacebookMessagesRealtimeTest < ActionView::TestCase
  include AccountTestHelper
  include GroupsTestHelper
  include FacebookTestHelper
  include Facebook::Constants

  def teardown
    Social::FacebookPage.any_instance.stubs(:unsubscribe_realtime).returns(true)
    @account ||= Account.first
    @account.facebook_pages.destroy_all
    @account.facebook_streams.destroy_all
    @account.rollback(:fb_message_echo_support)
    @account.tickets.where(source: Helpdesk::Source::FACEBOOK).destroy_all
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
    Account.unstub(:current)
    super
  ensure
    Social::FacebookPage.any_instance.unstub(:unsubscribe_realtime)
  end

  def setup
    Account.stubs(:current).returns(Account.first)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 200, text: '{"pages": [{"id": 568, "freshdeskAccountId": "1", "facebookPageId": "532218423476440"}], "meta": {"count": 1}}')
    @account = Account.current || Account.first
    @account.launch(:fb_message_echo_support)
    user = @account.nil? ? @account.users.first : create_test_account
    @fb_page = create_test_facebook_page(@account)
    @fb_page.update_attributes(realtime_messaging: true)
    @user_id = rand(10**10)
  end

  def test_dm_is_converted_to_a_ticket
    thread_id = rand(10**10)
    msg_id = thread_id + 20
    time = Time.now.utc

    realtime_dm_event = realtime_dms(@fb_page.page_id, msg_id, @user_id, time)
    sqs_msg = Hashit.new(body: realtime_dm_event.to_json)
    dm = sample_dms(thread_id, @user_id, msg_id, time)
    msg = dm['data'][0]['messages']['data'][0].deep_symbolize_keys
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(msg)
    Sqs::FacebookMessage.new(sqs_msg.body).process

    dm_msg_id = msg[:id]
    ticket = @account.facebook_posts.find_by_post_id(dm_msg_id).postable
    assert_equal ticket.is_a?(Helpdesk::Ticket), true
    assert_equal verify_ticket_properties(ticket, msg), true
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
  end

  def test_dm_is_converted_to_ticket_with_group
    group = create_group(@account)
    rule = @fb_page.dm_stream.ticket_rules[0]
    rule[:action_data][:group_id] = group.id
    rule.save!

    thread_id = rand(10**10)
    msg_id = thread_id + 20
    time = Time.now.utc

    realtime_dm_event = realtime_dms(@fb_page.page_id, msg_id, @user_id, time)
    sqs_msg = Hashit.new(body: realtime_dm_event.to_json)
    dm = sample_dms(thread_id, @user_id, msg_id, time)
    msg = dm['data'][0]['messages']['data'][0].deep_symbolize_keys
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(msg)
    Sqs::FacebookMessage.new(sqs_msg.body).process
    dm_msg_id = msg[:id]

    ticket = @account.facebook_posts.find_by_post_id(dm_msg_id).postable
    assert_equal ticket.is_a?(Helpdesk::Ticket), true
    assert_equal ticket.group_id, group.id
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
  end

  def test_second_dm_after_threading_interval_is_converted_into_a_new_ticket
    @fb_page.update_attributes(dm_thread_time: 3600)
    thread_id = rand(10**10)
    msg_id = thread_id + 20
    time = Time.now.utc

    realtime_dm_event = realtime_dms(@fb_page.page_id, msg_id, @user_id, time)
    sqs_msg = Hashit.new(body: realtime_dm_event.to_json)
    dm = sample_dms(thread_id, @user_id, msg_id, time)
    first_msg = dm['data'][0]['messages']['data'][0].deep_symbolize_keys
    second_msg = dm['data'][1]['messages']['data'][0].deep_symbolize_keys
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(first_msg, second_msg)
    Timecop.freeze(Time.now.utc + 1.hour) do
      Sqs::FacebookMessage.new(sqs_msg.body).process
    end
    first_msg_id = first_msg[:id]
    second_msg_id = second_msg[:id]
    assert_equal @account.facebook_posts.find_by_post_id(first_msg_id).postable.is_a?(Helpdesk::Ticket), true
    assert_equal @account.facebook_posts.find_by_post_id(second_msg_id).postable.is_a?(Helpdesk::Ticket), true
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
  end

  def test_second_dm_within_threading_interval_is_added_as_a_note_on_same_ticket
    thread_id = rand(10**10)
    msg_id = thread_id + 20
    time = Time.now.utc

    realtime_dm_event = realtime_dms(@fb_page.page_id, msg_id, @user_id, time)
    sqs_msg = Hashit.new(body: realtime_dm_event.to_json)
    dm = sample_dms(thread_id, @user_id, msg_id, time)
    first_msg = dm['data'][0]['messages']['data'][0].deep_symbolize_keys
    second_msg = dm['data'][1]['messages']['data'][0].deep_symbolize_keys
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(first_msg, second_msg)
    Sqs::FacebookMessage.new(sqs_msg.body).process

    first_msg_id = first_msg[:id]
    second_msg_id = second_msg[:id]
    assert_equal @account.facebook_posts.find_by_post_id(first_msg_id).postable.is_a?(Helpdesk::Ticket), true
    note = @account.facebook_posts.find_by_post_id(second_msg_id).postable
    assert_equal note.is_a?(Helpdesk::Note), true
    assert_equal verify_note_properties(note, second_msg), true
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
  end

  def test_convert_multiple_dm_messages_within_thread_interval_to_notes
    thread_id = "#{@fb_page.page_id.to_s}#{MESSAGE_THREAD_ID_DELIMITER}#{@user_id}"
    Timecop.travel(1.seconds)
    create_facebook_dm_as_ticket(@fb_page, thread_id, @user_id)

    msg_id = rand(10**10)
    time = Time.now.utc

    realtime_dm_event = realtime_dms(@fb_page.page_id, msg_id, @user_id, time)
    sqs_msg = Hashit.new(body: realtime_dm_event.to_json)
    dm = sample_dms(thread_id, @user_id, msg_id, time)
    first_msg = dm['data'][0]['messages']['data'][0].deep_symbolize_keys
    second_msg = dm['data'][1]['messages']['data'][0].deep_symbolize_keys
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(first_msg, second_msg)
    Sqs::FacebookMessage.new(sqs_msg.body).process
    first_msg_id = first_msg[:id]
    second_msg_id = second_msg[:id]
    assert_equal @account.facebook_posts.find_by_post_id(first_msg_id).postable.is_a?(Helpdesk::Note), true
    assert_equal @account.facebook_posts.find_by_post_id(second_msg_id).postable.is_a?(Helpdesk::Note), true
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
  end

  def test_do_not_convert_dm_when_import_dms_is_not_choosen
    @fb_page.update_attributes(import_dms: false)
    thread_id = rand(10**10)
    msg_id = thread_id + 20
    time = Time.now.utc

    realtime_dm_event = realtime_dms(@fb_page.page_id, msg_id, @user_id, time)
    sqs_msg = Hashit.new(body: realtime_dm_event.to_json)
    dm = sample_dms(thread_id, @user_id, msg_id, time)
    msg = dm['data'][0]['messages']['data'][0].deep_symbolize_keys
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(msg)
    Sqs::FacebookMessage.new(sqs_msg.body).process
    dm_msg_id = msg[:id]
    assert_nil @account.facebook_posts.find_by_post_id(dm_msg_id)
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
  end

  def test_should_create_new_ticket_with_recipient_thread_key_for_echo_message
    thread_id = rand(10**10)
    message_id = thread_id + 20
    time = Time.now.utc

    realtime_dm_event = realtime_dms(@fb_page.page_id, message_id, @user_id, time)
    realtime_dm_event['entry']['messaging'].first['message']['is_echo'] = true
    sqs_message = Hashit.new(body: realtime_dm_event.to_json)
    fb_message = sample_echo_message_fb_response(message_id, @user_id, @fb_page.page_id, time)
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(fb_message)
    Sqs::FacebookMessage.new(sqs_message.body).process

    dm_message_id = fb_message[:id]
    ticket = @account.facebook_posts.find_by_post_id(dm_message_id).postable
    assert_equal ticket.is_a?(Helpdesk::Ticket), true
    assert_equal verify_ticket_properties(ticket, fb_message, true), true
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
  end

  def test_should_create_new_note_when_threading_interval_not_exceeded_for_echo_message
    thread_id = rand(10**10)
    message_id = thread_id + 20
    time = Time.now.utc

    realtime_dm_event = realtime_dms(@fb_page.page_id, message_id, @user_id, time)
    realtime_dm_event['entry']['messaging'].each { |message| message['message']['is_echo'] = true }
    sqs_message = Hashit.new(body: realtime_dm_event.to_json)
    first_fb_message = sample_echo_message_fb_response(message_id, @user_id, @fb_page.page_id, time)
    second_fb_message = sample_echo_message_fb_response(message_id + 5, @user_id, @fb_page.page_id, time)
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(first_fb_message, second_fb_message)
    Sqs::FacebookMessage.new(sqs_message.body).process

    first_messsage_id = first_fb_message[:id]
    second_message_id = second_fb_message[:id]
    assert_equal @account.facebook_posts.find_by_post_id(first_messsage_id).postable.is_a?(Helpdesk::Ticket), true
    note = @account.facebook_posts.find_by_post_id(second_message_id).postable
    assert_equal note.is_a?(Helpdesk::Note), true
    assert_equal verify_note_properties(note, second_fb_message), true
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
  end

  def test_should_construct_generic_ticket_subject_when_fb_message_not_present
    thread_id = rand(10**10)
    message_id = thread_id + 20
    time = Time.now.utc

    realtime_dm_event = realtime_dms(@fb_page.page_id, message_id, @user_id, time)
    realtime_dm_event['entry']['messaging'].first['message']['is_echo'] = true
    sqs_message = Hashit.new(body: realtime_dm_event.to_json)
    fb_message = sample_echo_message_fb_response(message_id, @user_id, @fb_page.page_id, time)
    fb_message[:message] = nil
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(fb_message)
    Sqs::FacebookMessage.new(sqs_message.body).process

    dm_message_id = fb_message[:id]
    ticket = @account.facebook_posts.find_by_post_id(dm_message_id).postable
    assert_equal ticket.subject, I18n.t('facebook.page_message_subject', from_name: @fb_page.page_name, to_name: fb_message[:to][:data].first[:name])
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
  end

  def test_should_not_convert_echo_message_to_ticket_when_fb_message_echo_support_launch_party_is_not_launched
    thread_id = rand(10**10)
    message_id = thread_id + 20
    time = Time.now.utc
    @account.rollback(:fb_message_echo_support)

    realtime_dm_event = realtime_dms(@fb_page.page_id, message_id, @user_id, time)
    realtime_dm_event['entry']['messaging'].first['message']['is_echo'] = true
    sqs_message = Hashit.new(body: realtime_dm_event.to_json)
    first_fb_message = sample_echo_message_fb_response(message_id, @user_id, @fb_page.page_id, time)
    second_fb_message = sample_echo_message_fb_response(message_id + 5, @user_id, @fb_page.page_id, time)
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(second_fb_message)
    Sqs::FacebookMessage.new(sqs_message.body).process

    first_dm_message_id = first_fb_message[:id]
    second_dm_message_id = second_fb_message[:id]
    assert_nil @account.facebook_posts.find_by_post_id(first_dm_message_id)
    ticket = @account.facebook_posts.find_by_post_id(second_dm_message_id).postable
    assert_equal ticket.is_a?(Helpdesk::Ticket), true
    assert_equal verify_ticket_properties(ticket, second_fb_message, true), true
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
  end
end
