require_relative '../../test_helper'
['social_tickets_creation_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class NoteTest < ActiveSupport::TestCase
  include TicketsTestHelper
  include NotesTestHelper
  include ModelsAttachmentsTestHelper
  include SocialTicketsCreationHelper

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account.subscription.state = 'active'
    @account.subscription.save
    # @account.add_feature(:freshcaller)
    # ::Freshcaller::Account.new(account_id: @account.id).save
    @account.reload
    @account.save
    @ticket = create_ticket
    @@before_all_run = true
  end

  def test_central_publish
    CentralPublishWorker::ActiveNoteWorker.jobs.clear
    note = create_note(note_params_hash)
    assert_equal 1, CentralPublishWorker::ActiveNoteWorker.jobs.size
  end

  def test_central_publish_payload
    note = create_note(note_params_hash)
    payload = note.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_note_pattern(note))
    assoc_payload = note.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(central_assoc_note_pattern(note))
  end

  def test_central_publish_payload_event_info
    note = create_note(note_params_hash)
    payload = note.central_publish_payload.to_json
    event_info = note.event_info(:create)
    payload.must_match_json_expression(central_publish_note_pattern(note))
    event_info.must_match_json_expression(event_info(note, :create))
  end

  def test_central_publish_payload_event_info_check_hypertrail_version
    note = create_note(note_params_hash)
    payload = note.central_publish_payload.to_json
    create_event_info = note.event_info(:create)
    assert_equal CentralConstants::HYPERTRAIL_VERSION, create_event_info[:hypertrail_version]
    payload.must_match_json_expression(central_publish_note_pattern(note))
    create_event_info.must_match_json_expression(event_info(note, :create))
  ensure
    note.destroy
  end

  def test_central_publish_payload_event_info_on_note_with_twitter_feed_note_activity
    note = create_note(note_params_hash)
    note.activity_type = { type: Social::Constants::TWITTER_FEED_NOTE }
    create_event_info = note.event_info(:create)
    assert_equal Social::Constants::TWITTER_FEED_NOTE, create_event_info[:activity_type][:type]
    payload = note.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_note_pattern(note))
    create_event_info.must_match_json_expression(event_info(note, :create))
  ensure
    note.destroy
  end

  # def test_central_publish_payload_for_notes_having_freshcaller
  #   create_note_with_freshcaller
  #   note = create_note_with_freshcaller(note_params_hash)
  #   payload = note.central_publish_payload.to_json
  #   payload.must_match_json_expression(central_publish_note_pattern(note))
  #   assoc_payload = note.associations_to_publish.to_json
  #   assoc_payload.must_match_json_expression(central_assoc_note_pattern(note))
  # end

  def test_central_publish_update_action
    note = create_note(note_params_hash)
    note = Helpdesk::Note.find(note.id)
    CentralPublishWorker::ActiveNoteWorker.jobs.clear
    note.update_attributes(source: Account.current.helpdesk_sources.note_source_keys_by_token["email"])
    note.reload
    payload = note.central_publish_payload.to_json    
    payload.must_match_json_expression(central_publish_note_pattern(note))
    assert_equal 1, CentralPublishWorker::ActiveNoteWorker.jobs.size
    job = CentralPublishWorker::ActiveNoteWorker.jobs.last
    assert_equal 'note_update', job['args'][0]
    assert_equal({"source"=>[2, 0]}, job['args'][1]['model_changes'])
  end

  # def test_note_central_publish_payload_for_notes_having_tweet
  #   handle = create_test_twitter_handle(@account)
  #   @stream = handle.default_stream

  #   tweet_feed = sample_gnip_feed(@account, @stream)
  #   sqs_msg = Hashit.new(body: tweet_feed.to_json)
  #   response = Ryuken::TwitterTweetToTicket.new.perform(sqs_msg, nil)
  #   ticket = @account.tickets.last
  #   tweet_id = ticket.tweet.tweet_id
  #   @account.make_current
  #   reply_feed = sample_gnip_feed(@account, @stream, tweet_id)
  #   sqs_msg = Hashit.new(body: reply_feed.to_json)
  #   Ryuken::TwitterTweetToTicket.new.perform(sqs_msg, nil)
  #   @account.make_current
  #   note = ticket.notes.last
  #   payload = note.central_publish_payload.to_json
  #   payload.must_match_json_expression(central_publish_note_pattern(note))
  #   assoc_payload = note.associations_to_publish.to_json
  #   assoc_payload.must_match_json_expression(central_assoc_note_pattern(note))
  #   Account.reset_current_account
  # end

  # def test_note_central_publish_payload_for_notes_having_fb
  #   @fb_page = create_test_facebook_page(@account)
  #   @fb_page.update_attributes(import_visitor_posts: true)
  #   rule = @fb_page.default_stream.ticket_rules[0]
  #   rule[:filter_data] = { rule_type: RULE_TYPE[:broad] }
  #   rule.save!

  #   user_id = rand(10**10)
  #   post_id = rand(10**15)
  #   comment_id = rand(10**15)
  #   time = Time.now.utc
  #   post_user_id = @fb_page.page_id

  #   comment_feed = sample_realtime_comment(@fb_page.page_id, post_id, comment_id, user_id, time)
  #   koala_post = sample_post_feed(@fb_page.page_id, post_user_id, post_id, time)    
  #   koala_comment = sample_comment_feed(post_id, user_id, comment_id, time)
  #   koala_post[0]['comments'] = koala_comment
  #   sqs_msg = Hashit.new(body: comment_feed.to_json)

  #   Koala::Facebook::API.any_instance.stubs(:get_object).returns(koala_comment['data'][0], koala_post[0])
  #   Ryuken::FacebookRealtime.new.perform(sqs_msg)
  #   Koala::Facebook::API.any_instance.unstub(:get_object)
  #   fb_post_id = koala_post[0]['id']
  #   fb_comment_id = koala_comment['data'][0]['id']
  #   note = @account.facebook_posts.find_by_post_id(fb_comment_id).postable
  #   payload = note.central_publish_payload.to_json
  #   payload.must_match_json_expression(central_publish_note_pattern(note))
  #   assoc_payload = note.associations_to_publish.to_json
  #   assoc_payload.must_match_json_expression(central_assoc_note_pattern(note))
  # end

  def test_note_create_with_notifier_ids
    @ticket = Helpdesk::Ticket.last
    note = create_note_with_notifier(@ticket)
    payload = note.central_publish_payload.to_json
    event_info = note.event_info(:create)
    payload.must_match_json_expression(central_publish_note_pattern(note))
    event_info.must_match_json_expression(event_info(note, :create))
  end

  def test_note_central_publish_payload_for_note_containing_survey_remark
    @ticket = Helpdesk::Ticket.last
    note = create_note_with_survey_result(@ticket)
    note.update_attributes({body: "A happy survey"})
    payload = note.central_publish_payload.to_json    
    payload.must_match_json_expression(central_publish_note_pattern(note))
    job = CentralPublishWorker::ActiveNoteWorker.jobs.last
    assoc_payload = note.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(central_assoc_note_pattern(note))
  end

  def test_central_publish_payload_with_source_additional_info_facebook
    ticket = create_fb_ticket
    note = create_note(source: 7, ticket_id: ticket.id, user_id: ticket.requester_id, private: false, body: Faker::Lorem.paragraph)
    note.build_fb_post({
      post_id: Faker::Number.number(12),
      facebook_page_id: ticket.fb_post.facebook_page_id,
      account_id: ticket.account_id,
      parent_id: ticket.fb_post.id,
      post_attributes: {
        can_comment: false,
        post_type: 3
      }
    })
    note.save
    note.reload
    payload = note.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_note_pattern(note))
  end

  def test_central_publish_payload_with_source_additional_info_facebook_with_parent
    ticket = create_fb_post_ticket
    ticket.reload
    note = create_note(source: 7, ticket_id: ticket.id, user_id: ticket.requester_id, private: false, body: Faker::Lorem.paragraph)
    note.build_fb_post({
      post_id: Faker::Number.number(12),
      facebook_page_id: ticket.fb_post.facebook_page_id,
      account_id: ticket.account_id,
      parent_id: ticket.fb_post.id,
      post_attributes: {
        can_comment: false,
        post_type: 3
      }
    })
    note.save
    note.reload
    payload = note.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_note_pattern(note))
  end

  def test_source_additional_info_fb_page_destroy_note_update
    ticket = create_fb_ticket
    note = create_note(source: 7, ticket_id: ticket.id, user_id: ticket.requester_id, private: false, body: Faker::Lorem.paragraph)
    note.build_fb_post({
      post_id: Faker::Number.number(12),
      facebook_page_id: ticket.fb_post.facebook_page_id,
      account_id: ticket.account_id,
      parent_id: ticket.fb_post.id,
      post_attributes: {
        can_comment: false,
        post_type: 3
      }
    })
    ticket.fb_post.facebook_page.delete
    note.update_attributes(body: Faker::Lorem.paragraph)
    payload = note.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_note_pattern(note))
  end

  def test_central_publish_payload_with_source_additional_info_twitter
    ticket = create_twitter_ticket
    note = create_note(source: 5, ticket_id: ticket.id, user_id: ticket.requester_id, private: false, body: Faker::Lorem.paragraph)
    ticket.tweet.twitter_handle.delete
    note.update_attributes(body: Faker::Lorem.paragraph)
    payload = note.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_note_pattern(note))
  end

  def test_source_additional_info_twitter_handle_destroy_note_update
    ticket = create_twitter_ticket(tweet_type: 'dm')
    note = create_note(source: 5, ticket_id: ticket.id, user_id: ticket.requester_id, private: false, body: Faker::Lorem.paragraph)
    ticket.tweet.twitter_handle.delete
    note.update_attributes(body: Faker::Lorem.paragraph)
    payload = note.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_note_pattern(note))
  end

  def test_central_publish_payload_with_source_additional_info_email
    note = create_note(note_params_hash)
    note.schema_less_note.note_properties = {}
    note.schema_less_note.note_properties[:received_at] = Time.now.utc.iso8601
    payload = note.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_note_pattern(note))
  end

  def test_central_publish_payload_with_source_additional_info_email_nil
    note = create_note(note_params_hash)
    note.schema_less_note.note_properties = {}
    note.schema_less_note.note_properties[:received_at] = nil
    payload = note.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_note_pattern(note))
  end

  def test_central_publish_payload_with_source_additional_info_email_no_header_hash
    note = create_note(note_params_hash)
    note.schema_less_note.note_properties = nil
    payload = note.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_note_pattern(note))
  end

  def test_note_central_payload_update_ticket_states_worker
    note = create_note(note_params_hash)
    input = {
      id: note.id,
      model_changes: nil,
      freshdesk_webhook: false,
      current_user_id: @agent.id
    }
    CentralPublishWorker::ActiveNoteWorker.jobs.clear
    Tickets::UpdateTicketStatesWorker.new.perform(input)
    assert_equal 1, CentralPublishWorker::ActiveNoteWorker.jobs.size
    job = CentralPublishWorker::ActiveNoteWorker.jobs.last
    schema_less_note = note.schema_less_note.reload
    assert_equal 'note_update', job['args'][0]
    assert_equal({ 'response_time_in_seconds' => [nil, schema_less_note.response_time_in_seconds],
                   'response_time_by_bhrs' => [nil, schema_less_note.response_time_by_bhrs] }, job['args'][1]['model_changes'])
  end

  def test_note_central_payload_with_response_violation
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
    t = create_ticket
    t.nr_due_by = Time.zone.now
    t.save
    CentralPublishWorker::ActiveNoteWorker.jobs.clear
    note = create_note(source: 2, ticket_id: t.id, user_id: @agent.id, private: false, body: Faker::Lorem.paragraph)
    payload = note.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_note_pattern(note))
    assert_equal 1, CentralPublishWorker::ActiveNoteWorker.jobs.size
    job = CentralPublishWorker::ActiveNoteWorker.jobs.last
    assert_equal 'note_create', job['args'][0]
  ensure
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_note_central_payload_manual_publish
    note = create_note(note_params_hash)
    CentralPublishWorker::ActiveNoteWorker.jobs.clear
    note.manual_publish_to_central(nil, :create, {})
    assert_equal 1, CentralPublishWorker::ActiveNoteWorker.jobs.size
    job = CentralPublishWorker::ActiveNoteWorker.jobs.last
    assert_equal false, job['args'][1]['event_info']['app_update']
  end
end
