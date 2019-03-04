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
    super
    @account.facebook_pages.destroy_all
    @account.facebook_streams.destroy_all
    @account.tickets.where(source: Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:facebook]).destroy_all
    Account.unstub(:current)
    WebMock.disable_net_connect!
  ensure
    Social::FacebookPage.any_instance.unstub(:unsubscribe_realtime)
    Facebook::Core::Post.any_instance.unstub(:fetch_page_scope_id)
    Facebook::Core::Comment.any_instance.unstub(:fetch_page_scope_id)
    Facebook::Core::ReplyToComment.any_instance.unstub(:fetch_page_scope_id)
    Facebook::Core::Status.any_instance.unstub(:fetch_page_scope_id)
  end

  def setup
    Webmock.allow_net_connect!
    Account.stubs(:current).returns(Account.first)
    Facebook::Core::Post.any_instance.stubs(:fetch_page_scope_id).returns(nil)
    Facebook::Core::Comment.any_instance.stubs(:fetch_page_scope_id).returns(nil)
    Facebook::Core::ReplyToComment.any_instance.stubs(:fetch_page_scope_id).returns(nil)
    Facebook::Core::Status.any_instance.stubs(:fetch_page_scope_id).returns(nil)
    @account = Account.current
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
    msg = dm[0]['messages']['data'][0]
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
    msg = dm[0]['messages']['data'][0]
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
    first_msg = dm[0]['messages']['data'][0]
    second_msg = dm[1]['messages']['data'][0]
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
    first_msg = dm[0]['messages']['data'][0]
    second_msg = dm[1]['messages']['data'][0]
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
    first_msg = dm[0]['messages']['data'][0]
    second_msg = dm[1]['messages']['data'][0]
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
    msg = dm[0]['messages']['data'][0]
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(msg)
    Sqs::FacebookMessage.new(sqs_msg.body).process
    dm_msg_id = msg['id']
    assert_nil @account.facebook_posts.find_by_post_id(dm_msg_id)
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
  end
end
