require_relative '../../test_helper'

class NoteTest < ActiveSupport::TestCase
  include TicketsTestHelper
  include NotesTestHelper
  include AttachmentsTestHelper

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account.subscription.state = 'active'
    @account.subscription.save
    @account.launch(:note_central_publish)
    # @account.add_feature(:freshcaller)
    # ::Freshcaller::Account.new(account_id: @account.id).save
    @account.reload
    @account.save

    @ticket = create_ticket
    @@before_all_run = true
  end

  def test_central_publish_with_launch_party_disabled
    @account.rollback(:note_central_publish)
    CentralPublishWorker::ActiveNoteWorker.jobs.clear
    note = create_note(note_params_hash)
    assert_equal 0, CentralPublishWorker::ActiveNoteWorker.jobs.size
  ensure
    @account.launch(:note_central_publish)
  end

  def test_central_publish_with_launch_party_enabled
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
    note.update_attributes(source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["email"])
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
end
