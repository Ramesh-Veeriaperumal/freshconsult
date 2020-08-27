require_relative '../unit_test_helper'
require_relative '../../test_transactions_fixtures_helper'

require Rails.root.join('test', 'api', 'helpers', 'facebook_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'groups_test_helper.rb')

class FacebookRealtimeTest < ActionView::TestCase
  include FacebookTestHelper
  include GroupsTestHelper
  include Facebook::Constants

  def teardown
    super
    @account.facebook_streams.destroy_all
    @account.facebook_pages.destroy_all
    @account.tickets.where(source: Account.current.helpdesk_sources.ticket_source_keys_by_token[:facebook]).destroy_all
    Social::FacebookPage.any_instance.unstub(:unsubscribe_realtime)
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
    Account.unstub(:current)
  end

  def setup
    Account.stubs(:current).returns(Account.first)
    Social::FacebookPage.any_instance.stubs(:unsubscribe_realtime).returns(true)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 200, text: '{"pages": [{"id": 568, "freshdeskAccountId": "1", "facebookPageId": "532218423476440"}], "meta": {"count": 1}}')
    @account = Account.current
    @fb_page = create_test_facebook_page(@account)
    @fb_page.update_attributes(import_visitor_posts: true)
  end

  def test_do_not_convert_posts_with_strict_rule_type
    rule = @fb_page.default_stream.ticket_rules[0]
    rule[:filter_data] = { rule_type: RULE_TYPE[:strict] }
    rule.save!

    user_id = rand(10**10)
    post_id = rand(10**15)
    time = Time.now.utc

    realtime_feed = sample_realtime_post(@fb_page.page_id, post_id, user_id, time)
    sqs_msg = Hashit.new(body: realtime_feed.to_json)
    koala_post = sample_post_feed(@fb_page.page_id, user_id, post_id, time)
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
    Koala::Facebook::API.any_instance.unstub(:get_object)
    assert_nil @account.facebook_posts.find_by_post_id(post_id)
  end

  def test_convert_visitor_posts_to_ticket_with_optimal_rule_type
    user_id = rand(10**10)
    post_id = rand(10**10)
    time = Time.now.utc

    realtime_feed = sample_realtime_post(@fb_page.page_id, post_id, user_id, time)
    sqs_msg = Hashit.new(body: realtime_feed.to_json)
    koala_post = sample_post_feed(@fb_page.page_id, user_id, post_id, time)
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
    Koala::Facebook::API.any_instance.unstub(:get_object)
    fb_post_id = "#{@fb_page.page_id}_#{post_id}"
    fb_user_id = koala_post[0]['from']['id']
    message = koala_post[0]['message']
    post_created_at = Time.zone.parse(koala_post[0]['created_time'])
    ticket = @account.facebook_posts.find_by_post_id(fb_post_id).postable
    assert_equal ticket.is_a?(Helpdesk::Ticket), true

    assert_equal ticket.requester.fb_profile_id, fb_user_id
    assert_equal ticket.description, message
    assert_equal ticket.source, Account.current.helpdesk_sources.ticket_source_keys_by_token[:facebook]
    assert_equal ticket.created_at, post_created_at
  end

  def test_convert_visitor_posts_to_ticket_with_group
    group = create_group(@account)
    rule = @fb_page.default_stream.ticket_rules[0]
    rule[:action_data][:group_id] = group.id
    rule.save!

    user_id = rand(10**10)
    post_id = rand(10**10)
    time = Time.now.utc

    realtime_feed = sample_realtime_post(@fb_page.page_id, post_id, user_id, time)
    sqs_msg = Hashit.new(body: realtime_feed.to_json)
    koala_post = sample_post_feed(@fb_page.page_id, user_id, post_id, time)
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
    Koala::Facebook::API.any_instance.unstub(:get_object)

    fb_post_id = "#{@fb_page.page_id}_#{post_id}"
    ticket = @account.facebook_posts.find_by_post_id(fb_post_id).postable
    assert_equal ticket.group_id, group.id
    @account.groups.find(group.id).destroy
  end

  def test_do_not_convert_company_posts_with_optimal_rule_type
    user_id = @fb_page.page_id
    post_id = rand(10**15)
    time = Time.now.utc

    feed = sample_realtime_post(@fb_page.page_id, post_id, user_id, time)
    sqs_msg = Hashit.new(body: feed.to_json)
    koala_post = sample_post_feed(@fb_page.page_id, user_id, post_id, time)
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
    Koala::Facebook::API.any_instance.unstub(:get_object)
    assert_nil @account.facebook_posts.find_by_post_id(post_id)
  end

  def test_comments_to_company_post_convert_to_ticket_with_optimal_rule_type
    user_id = rand(10**10)
    post_id = rand(10**15)
    comment_id = rand(10**15)
    time = Time.now.utc
    post_user_id = @fb_page.page_id

    comment_feed = sample_realtime_comment(@fb_page.page_id, post_id, comment_id, user_id, time)
    koala_post = sample_post_feed(@fb_page.page_id, post_user_id, post_id, time)
    koala_comment = sample_comment_feed(post_id, user_id, comment_id, time)
    koala_post[0]['comments'] = koala_comment
    sqs_msg = Hashit.new(body: comment_feed.to_json)

    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_comment['data'][0], koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
    Koala::Facebook::API.any_instance.unstub(:get_object)
    fb_comment_id = koala_comment['data'][0]['id']
    comment_content = koala_comment['data'][0]['message']
    fb_post = @account.facebook_posts.find_by_post_id(fb_comment_id).postable
    assert_equal fb_post.is_a?(Helpdesk::Ticket), true    
    assert_equal fb_post.description, comment_content
  end

  def test_comments_to_company_post_convert_to_ticket_with_optimal_rule_type_link
    user_id = rand(10**10)
    post_id = rand(10**15)
    comment_id = rand(10**15)
    time = Time.now.utc
    post_user_id = @fb_page.page_id

    comment_feed = sample_realtime_comment(@fb_page.page_id, post_id, comment_id, user_id, time)
    koala_post = [{
      'id'              => "#{@fb_page.page_id}_#{post_id}",
      'type'            => 'post',
      'from'            => {
        'name'          => Faker::Lorem.words(1).to_s,
        'id'            => post_user_id.to_s
      },
      'message'         => 'https://www.facebook.com/',
      'created_time'    => time.to_s,
      'updated_time'    => Time.now.utc.to_s
    }]
    koala_comment = {
      'data'            => [
        'id'            => "#{post_id}_#{comment_id}",
        'from'          => {
          'name'        => Faker::Lorem.words(1).to_s,
          'id'          => user_id.to_s
        },
        'type'          => 'link',
        'can_comment'   => true,
        'created_time'  => time.to_s,
        'message'       => "Support #{Faker::Lorem.words(20).join(' ')}"
      ]
    }
    koala_post[0]['comments'] = koala_comment
    sqs_msg = Hashit.new(body: comment_feed.to_json)

    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_comment['data'][0], koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
    Koala::Facebook::API.any_instance.unstub(:get_object)
    fb_comment_id = koala_comment['data'][0]['id']
    comment_content = koala_comment['data'][0]['message']
    fb_post = @account.facebook_posts.find_by_post_id(fb_comment_id).postable
    assert_equal fb_post.is_a?(Helpdesk::Ticket), true
    assert_equal fb_post.description, comment_content
  end

  def test_convert_visitor_posts_to_ticket_with_broad_rule_type
    rule = @fb_page.default_stream.ticket_rules[0]
    rule[:filter_data] = { rule_type: RULE_TYPE[:broad] }
    rule.save!

    user_id = rand(10**10)
    post_id = rand(10**15)
    time = Time.now.utc

    feed = sample_realtime_post(@fb_page.page_id, post_id, user_id, time)
    sqs_msg = Hashit.new(body: feed.to_json)
    koala_post = sample_post_feed(@fb_page.page_id, user_id, post_id, time)
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
    Koala::Facebook::API.any_instance.unstub(:get_object)
    fb_post_id = "#{@fb_page.page_id}_#{post_id}"
    assert_equal @account.facebook_posts.find_by_post_id(fb_post_id).postable.is_a?(Helpdesk::Ticket), true
  end

  def test_convert_comments_to_visitor_post_as_notes_on_the_same_ticket_by_post_with_broad_rule_type
    rule = @fb_page.default_stream.ticket_rules[0]
    rule[:filter_data] = { rule_type: RULE_TYPE[:broad] }
    rule.save!

    user_id = rand(10**10)
    post_id = rand(10**15)
    comment_id = rand(10**15)
    time = Time.now.utc

    comment_feed = sample_realtime_comment(@fb_page.page_id, user_id, comment_id, user_id, time)
    koala_post = sample_post_feed(@fb_page.page_id, user_id, post_id, time)    
    koala_comment = sample_comment_feed(post_id, user_id, comment_id, time)
    koala_post[0]['comments'] = koala_comment
    sqs_msg = Hashit.new(body: comment_feed.to_json)

    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_comment['data'][0], koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
    Koala::Facebook::API.any_instance.unstub(:get_object)
    fb_post_id = koala_post[0]['id']

    fb_comment_id = koala_comment['data'][0]['id']
    comment_content = koala_comment['data'][0]['message']
    comment_user = koala_comment['data'][0]['from']['id']
    comment_time = Time.zone.parse(koala_comment['data'][0]['created_time'])

    assert_equal @account.facebook_posts.find_by_post_id(fb_post_id).postable.is_a?(Helpdesk::Ticket), true
    note = @account.facebook_posts.find_by_post_id(fb_comment_id).postable
    assert_equal note.is_a?(Helpdesk::Note), true
    assert_equal note.source, Account.current.helpdesk_sources.note_source_keys_by_token['facebook']
    assert_equal note.body, comment_content
    assert_equal note.user.fb_profile_id, comment_user
    assert_equal note.created_at, comment_time

  end

  def test_do_not_convert_company_posts_with_broad_rule_type
    rule = @fb_page.default_stream.ticket_rules[0]
    rule[:filter_data] = { rule_type: RULE_TYPE[:broad] }
    rule.save!

    user_id = @fb_page.page_id
    post_id = rand(10**15)
    time = Time.now.utc

    feed = sample_realtime_post(@fb_page.page_id, post_id, user_id, time)
    sqs_msg = Hashit.new(body: feed.to_json)
    koala_post = sample_post_feed(@fb_page.page_id, user_id, post_id, time)
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
    Koala::Facebook::API.any_instance.unstub(:get_object)
    assert_nil @account.facebook_posts.find_by_post_id(post_id)
  end

  def test_convert_comments_to_company_posts_add_as_note_on_same_ticket_as_post_with_broad_rule_type
    rule = @fb_page.default_stream.ticket_rules[0]
    rule[:filter_data] = { rule_type: RULE_TYPE[:broad] }
    rule.save!

    user_id = rand(10**10)
    post_id = rand(10**15)
    comment_id = rand(10**15)
    time = Time.now.utc
    post_user_id = @fb_page.page_id

    comment_feed = sample_realtime_comment(@fb_page.page_id, post_id, comment_id, user_id, time)
    koala_post = sample_post_feed(@fb_page.page_id, post_user_id, post_id, time)    
    koala_comment = sample_comment_feed(post_id, user_id, comment_id, time)
    koala_post[0]['comments'] = koala_comment
    sqs_msg = Hashit.new(body: comment_feed.to_json)

    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_comment['data'][0], koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
    Koala::Facebook::API.any_instance.unstub(:get_object)
    fb_post_id = koala_post[0]['id']
    fb_comment_id = koala_comment['data'][0]['id']
    assert_equal @account.facebook_posts.find_by_post_id(fb_post_id).postable.is_a?(Helpdesk::Ticket), true
    assert_equal @account.facebook_posts.find_by_post_id(fb_comment_id).postable.is_a?(Helpdesk::Note), true
  end

  def test_comments_to_company_post_convert_to_ticket_with_optimal_rule_type_with_no_includes
    user_id = rand(10 ** 10)
    post_id = rand(10 ** 15)
    comment_id = rand(10 ** 15)
    time = Time.now.utc
    post_user_id = @fb_page.page_id
    ticket_rule = @fb_page.default_ticket_rule
    filter_data_hash = ticket_rule.filter_data
    filter_data_hash[:includes] = []
    ticket_rule.filter_data = filter_data_hash
    ticket_rule.save!
    comment_feed = sample_realtime_comment(@fb_page.page_id, post_id, comment_id, user_id, time)
    koala_post = sample_post_feed(@fb_page.page_id, post_user_id, post_id, time)
    koala_comment = sample_comment_feed(post_id, user_id, comment_id, time)
    koala_post[0]['comments'] = koala_comment
    sqs_msg = Hashit.new(body: comment_feed.to_json)

    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_comment['data'][0], koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
    Koala::Facebook::API.any_instance.unstub(:get_object)
    fb_comment_id = koala_comment['data'][0]['id']
    comment_content = koala_comment['data'][0]['message']
    fb_post = @account.facebook_posts.find_by_post_id(fb_comment_id).postable
    assert_equal fb_post.is_a?(Helpdesk::Ticket), true
    assert_equal fb_post.description, comment_content
  end

  def test_comments_on_a_cover_photo_coverted_to_ticket
    user_id = rand(10**10)
    post_id = rand(10**15)
    comment_id = rand(10**15)
    parent_id = rand(10**15)
    cover_feed_id = rand(10**10)
    time = Time.now.utc
    post_user_id = @fb_page.page_id
    comment_feed = sample_realtime_comment(@fb_page.page_id, post_id, comment_id, user_id, time, parent_id)
    koala_comment = sample_comment_feed(post_id, user_id, comment_id, time)
    message = koala_comment['data'][0]['message']
    koala_post = sample_cover_photo_feed(@fb_page.page_id, post_user_id, cover_feed_id, time, message)
    sqs_msg = Hashit.new(body: comment_feed.to_json)
    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_comment['data'][0], koala_post[0], koala_comment['data'][0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
    Koala::Facebook::API.any_instance.unstub(:get_object)
    fb_comment_id = koala_comment['data'][0]['id']
    comment_content = koala_comment['data'][0]['message']
    fb_post = @account.facebook_posts.find_by_post_id(fb_comment_id).postable
    assert_equal fb_post.is_a?(Helpdesk::Ticket), true
    assert_equal fb_post.description, comment_content
  end

  def test_do_not_convert_company_post_comments_to_ticket_with_message_tags_when_filter_mentions_enabled
    user_id = rand(10**10)
    post_id = rand(10**15)
    comment_id = rand(10**15)
    time = Time.now.utc
    post_user_id = @fb_page.page_id
    ticket_rule = @fb_page.default_ticket_rule
    filter_data_hash = ticket_rule.filter_data
    filter_data_hash[:includes] = []
    filter_data_hash[:filter_mentions] = true
    ticket_rule.filter_data = filter_data_hash
    ticket_rule.save!
    comment_feed = sample_realtime_comment(@fb_page.page_id, post_id, comment_id, user_id, time)
    koala_post = sample_post_feed(@fb_page.page_id, post_user_id, post_id, time)
    koala_comment = sample_comment_feed_with_mentions(post_id, user_id, comment_id, time)
    koala_post[0]['comments'] = koala_comment
    sqs_msg = Hashit.new(body: comment_feed.to_json)

    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_comment['data'][0], koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
    fb_comment_id = koala_comment['data'][0]['id']
    assert_nil @account.facebook_posts.where(post_id: fb_comment_id).first
  end

  def test_convert_company_post_comments_to_ticket_with_message_tags_when_filter_mentions_disabled
    user_id = rand(10**10)
    post_id = rand(10**15)
    comment_id = rand(10**15)
    time = Time.now.utc
    post_user_id = @fb_page.page_id
    ticket_rule = @fb_page.default_ticket_rule
    filter_data_hash = ticket_rule.filter_data
    filter_data_hash[:includes] = []
    filter_data_hash[:filter_mentions] = false
    ticket_rule.filter_data = filter_data_hash
    ticket_rule.save!
    comment_feed = sample_realtime_comment(@fb_page.page_id, post_id, comment_id, user_id, time)
    koala_post = sample_post_feed(@fb_page.page_id, post_user_id, post_id, time)
    koala_comment = sample_comment_feed_with_mentions(post_id, user_id, comment_id, time)
    koala_post[0]['comments'] = koala_comment
    sqs_msg = Hashit.new(body: comment_feed.to_json)

    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_comment['data'][0], koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
    fb_comment_id = koala_comment['data'][0]['id']
    fb_post = @account.facebook_posts.where(post_id: fb_comment_id).first.postable
    assert fb_post.is_a?(Helpdesk::Ticket)
  end

  def test_do_not_convert_comments_to_visitor_post_as_notes_on_the_same_ticket_by_post_with_broad_rule_type_with_mentions_when_filter_mentions_enabled
    rule = @fb_page.default_stream.ticket_rules[0]
    rule[:filter_data] = { rule_type: RULE_TYPE[:broad], filter_mentions: true }
    rule.save!

    user_id = rand(10**10)
    post_id = rand(10**15)
    comment_id = rand(10**15)
    time = Time.now.utc

    comment_feed = sample_realtime_comment(@fb_page.page_id, user_id, comment_id, user_id, time)
    koala_post = sample_post_feed(@fb_page.page_id, user_id, post_id, time)
    koala_comment = sample_comment_feed_with_mentions(post_id, user_id, comment_id, time)
    koala_post[0]['comments'] = koala_comment
    sqs_msg = Hashit.new(body: comment_feed.to_json)

    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_comment['data'][0], koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)

    fb_comment_id = koala_comment['data'][0]['id']

    assert_nil @account.facebook_posts.where(post_id: fb_comment_id).first
  end

  def test_convert_comments_to_visitor_post_as_notes_on_the_same_ticket_by_post_with_broad_rule_type_with_mentions_when_filter_mentions_disabled
    rule = @fb_page.default_stream.ticket_rules[0]
    rule[:filter_data] = { rule_type: RULE_TYPE[:broad], filter_mentions: false }
    rule.save!

    user_id = rand(10**10)
    post_id = rand(10**15)
    comment_id = rand(10**15)
    time = Time.now.utc

    comment_feed = sample_realtime_comment(@fb_page.page_id, user_id, comment_id, user_id, time)
    koala_post = sample_post_feed(@fb_page.page_id, user_id, post_id, time)
    koala_comment = sample_comment_feed_with_mentions(post_id, user_id, comment_id, time)
    koala_post[0]['comments'] = koala_comment
    sqs_msg = Hashit.new(body: comment_feed.to_json)

    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_comment['data'][0], koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
    fb_post_id = koala_post[0]['id']

    fb_comment_id = koala_comment['data'][0]['id']

    assert @account.facebook_posts.where(post_id: fb_post_id).first.postable.is_a?(Helpdesk::Ticket)
    note = @account.facebook_posts.where(post_id: fb_comment_id).first.postable
    assert note.is_a?(Helpdesk::Note)
  end

  def test_do_not_convert_comments_to_company_posts_add_as_note_on_same_ticket_as_post_with_broad_rule_type_with_mentions_when_filter_mentions_enabled
    rule = @fb_page.default_stream.ticket_rules[0]
    rule[:filter_data] = { rule_type: RULE_TYPE[:broad], filter_mentions: true }
    rule.save!

    user_id = rand(10**10)
    post_id = rand(10**15)
    comment_id = rand(10**15)
    time = Time.now.utc
    post_user_id = @fb_page.page_id

    comment_feed = sample_realtime_comment(@fb_page.page_id, post_id, comment_id, user_id, time)
    koala_post = sample_post_feed(@fb_page.page_id, post_user_id, post_id, time)
    koala_comment = sample_comment_feed_with_mentions(post_id, user_id, comment_id, time)
    koala_post[0]['comments'] = koala_comment
    sqs_msg = Hashit.new(body: comment_feed.to_json)

    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_comment['data'][0], koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
    fb_comment_id = koala_comment['data'][0]['id']
    assert_nil @account.facebook_posts.where(post_id: fb_comment_id).first
  end

  def test_convert_comments_to_company_posts_add_as_note_on_same_ticket_as_post_with_broad_rule_type_with_mentions_when_filter_mentions_disabled
    rule = @fb_page.default_stream.ticket_rules[0]
    rule[:filter_data] = { rule_type: RULE_TYPE[:broad], filter_mentions: false }
    rule.save!

    user_id = rand(10**10)
    post_id = rand(10**15)
    comment_id = rand(10**15)
    time = Time.now.utc
    post_user_id = @fb_page.page_id

    comment_feed = sample_realtime_comment(@fb_page.page_id, post_id, comment_id, user_id, time)
    koala_post = sample_post_feed(@fb_page.page_id, post_user_id, post_id, time)
    koala_comment = sample_comment_feed_with_mentions(post_id, user_id, comment_id, time)
    koala_post[0]['comments'] = koala_comment
    sqs_msg = Hashit.new(body: comment_feed.to_json)

    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_comment['data'][0], koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
    fb_post_id = koala_post[0]['id']
    fb_comment_id = koala_comment['data'][0]['id']
    assert @account.facebook_posts.where(post_id: fb_post_id).first.postable.is_a?(Helpdesk::Ticket)
    note = @account.facebook_posts.where(post_id: fb_comment_id).first.postable
    assert note.is_a?(Helpdesk::Note)
  end

  def test_do_not_convert_comments_to_company_posts_add_as_note_on_same_ticket_as_post_with_broad_rule_type_with_multiple_mentions_and_special_chars_when_filter_mentions_enabled
    rule = @fb_page.default_stream.ticket_rules[0]
    rule[:filter_data] = { rule_type: RULE_TYPE[:broad], filter_mentions: true }
    rule.save!

    user_id = rand(10**10)
    post_id = rand(10**15)
    comment_id = rand(10**15)
    time = Time.now.utc
    post_user_id = @fb_page.page_id

    comment_feed = sample_realtime_comment(@fb_page.page_id, post_id, comment_id, user_id, time)
    koala_post = sample_post_feed(@fb_page.page_id, post_user_id, post_id, time)
    koala_comment = sample_comment_feed_with_multiple_mentions(post_id, user_id, comment_id, time)
    koala_post[0]['comments'] = koala_comment
    sqs_msg = Hashit.new(body: comment_feed.to_json)

    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_comment['data'][0], koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
    fb_comment_id = koala_comment['data'][0]['id']
    assert_nil @account.facebook_posts.where(post_id: fb_comment_id).first
  end

  def test_do_not_convert_comments_to_company_posts_add_as_note_on_same_ticket_as_post_with_broad_rule_type_with_mentions_and_emojis_when_filter_mentions_enabled
    rule = @fb_page.default_stream.ticket_rules[0]
    rule[:filter_data] = { rule_type: RULE_TYPE[:broad], filter_mentions: true }
    rule.save!

    user_id = rand(10**10)
    post_id = rand(10**15)
    comment_id = rand(10**15)
    time = Time.now.utc
    post_user_id = @fb_page.page_id

    comment_feed = sample_realtime_comment(@fb_page.page_id, post_id, comment_id, user_id, time)
    koala_post = sample_post_feed(@fb_page.page_id, post_user_id, post_id, time)
    koala_comment = sample_comment_feed_with_mentions_and_emojis(post_id, user_id, comment_id, time)
    koala_post[0]['comments'] = koala_comment
    sqs_msg = Hashit.new(body: comment_feed.to_json)

    Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_comment['data'][0], koala_post[0])
    Ryuken::FacebookRealtime.new.perform(sqs_msg, nil)
  ensure
    Koala::Facebook::API.any_instance.unstub(:get_object)
    fb_comment_id = koala_comment['data'][0]['id']
    assert_nil @account.facebook_posts.where(post_id: fb_comment_id).first
  end
end
