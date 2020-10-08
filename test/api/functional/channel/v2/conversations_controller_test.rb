require_relative '../../../test_helper'
['social_tickets_creation_helper.rb', 'twitter_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module Channel::V2
  class ConversationsControllerTest < ActionController::TestCase
    include ConversationsTestHelper
    include SocialTicketsCreationHelper
    include TwitterHelper
    include CentralLib::CentralResyncHelper
    include Redis::OthersRedis

    SOURCE = 'analytics'.freeze

    def setup
      super
      Twitter::REST::Client.any_instance.stubs(:user).returns(sample_twitter_user(Faker::Number.between(1, 999_999_999).to_s))
    end

    def teardown
      super
      Twitter::REST::Client.any_instance.unstub(:user)
    end

    def wrap_cname(params)
      { conversation: params }
    end

    def ticket
      ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
      ticket
    end

    def user
      user = other_user
      user
    end

    def note
      @agent.preferences[:agent_preferences][:undo_send] = false
      Helpdesk::Note.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['note'], deleted: false).first || create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
    end

    def create_note_params_hash
      {
        body: Faker::Lorem.paragraph,
        notify_emails: [Agent.first.user.email],
        private: true
      }
    end

    def reply_note_params_hash
      body = Faker::Lorem.paragraph
      email = [Faker::Internet.email, Faker::Internet.email]
      bcc_emails = [Faker::Internet.email, Faker::Internet.email]
      email_config = Account.current.email_configs.where(active: true).first || create_email_config
      params_hash = { body: body, cc_emails: email, bcc_emails: bcc_emails, from_email: email_config.reply_email }
      params_hash
    end

    def update_note_params_hash
      body = Faker::Lorem.paragraph
      params_hash = { body: body }
      params_hash
    end

    def test_create_with_created_at_updated_at
      created_at = updated_at = Time.now
      params_hash = create_note_params_hash.merge('created_at' => created_at,
                                                  'updated_at' => updated_at)
      post :create, construct_params({ version: 'v1', id: ticket.display_id }, params_hash)
      assert_response 201
      note = ticket.notes.last
      match_json(v2_note_pattern(params_hash.merge(category: 2), note))
      match_json(v2_note_pattern({}, note))
      assert (note.created_at - created_at).to_i == 0
      assert (note.updated_at - updated_at).to_i == 0
    end

    def test_create_with_ticket_trashed
      Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
      params_hash = create_note_params_hash
      post :create, construct_params({ id: ticket.display_id }, params_hash)
      Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end

    def test_create_without_ticket_privilege
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      params_hash = create_note_params_hash
      post :create, construct_params({ id: ticket.display_id }, params_hash)
      User.any_instance.unstub(:has_ticket_permission?)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end

    def test_create
      params_hash = create_note_params_hash
      post :create, construct_params({ id: ticket.display_id }, params_hash)
      assert_response 201
      match_json(v2_note_pattern(params_hash, Helpdesk::Note.last))
      match_json(v2_note_pattern({}, Helpdesk::Note.last))
    end

    def test_create_public_note
      params_hash = create_note_params_hash.merge(private: false)
      post :create, construct_params({ id: ticket.display_id }, params_hash)
      assert_response 201
      match_json(v2_note_pattern(params_hash, Helpdesk::Note.last))
      match_json(v2_note_pattern({}, Helpdesk::Note.last))
    end

    def test_update_note
      params = update_note_params_hash
      n = note
      put :update, construct_params({ id: n.id }, params)
      assert_response 200
      match_json(v2_update_note_pattern(params, Helpdesk::Note.find(n.id)))
      match_json(v2_update_note_pattern({}, Helpdesk::Note.find(n.id)))
    end

    def test_update_user_note
      user = add_new_user(@account)
      n = create_note(user_id: user.id, ticket_id: ticket.id, source: 2)
      params = update_note_params_hash
      put :update, construct_params({ id: n.id }, params)
      assert_response 200
    end

    def test_update_without_privilege
      User.any_instance.stubs(:privilege?).with(:edit_note).returns(false).at_most_once
      User.any_instance.stubs(:owns_object?).returns(false).at_most_once
      params = update_note_params_hash
      n = note
      put :update, construct_params({ id: n.id }, params)
      User.any_instance.unstub(:privilege?)
      User.any_instance.unstub(:owns_object?)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end

    def test_update_note_with_timestamps
      params = update_note_params_hash
      n = note
      created_at = updated_at = Time.current - 10.days
      params.merge!(created_at: created_at, updated_at: updated_at)
      put :update, construct_params({ id: n.id }, params)
      assert_response 200
      n = n.reload
      assert (n.created_at - created_at).to_i.zero?
      assert (n.updated_at - updated_at).to_i.zero?
    end

    def test_update_note_private_field
      params = update_note_params_hash
      n = note
      private_value = !n.private
      params.merge!(private: private_value)
      put :update, construct_params({ id: n.id }, params)
      assert_response 200
      n = n.reload
      assert_equal n.private, private_value
    end

    def test_update_note_validation_failure
      params = update_note_params_hash
      n = note
      current_time = '2020-05-10 08:08:08'
      params.merge!(created_at: current_time, updated_at: current_time)
      put :update, construct_params({ id: n.id }, params)
      assert_response 400
      match_json([
                   bad_request_error_pattern('created_at', :invalid_date, accepted: 'combined date and time ISO8601'),
                   bad_request_error_pattern('updated_at', :invalid_date, accepted: 'combined date and time ISO8601')
                  ])
    end

    def test_reply_with_ticket_trashed
      Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
      params_hash = reply_note_params_hash
      post :reply, construct_params({ id: ticket.display_id }, params_hash)
      Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end

    def test_reply_without_ticket_privilege
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      params_hash = reply_note_params_hash
      post :reply, construct_params({ id: ticket.display_id }, params_hash)
      User.any_instance.unstub(:has_ticket_permission?)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end

    def test_reply
      params_hash = reply_note_params_hash
      post :reply, construct_params({ id: ticket.display_id }, params_hash)
      assert_response 201
      match_json(v2_reply_note_pattern(params_hash, Helpdesk::Note.last))
      match_json(v2_reply_note_pattern({}, Helpdesk::Note.last))
    end

    def test_twitter_dm_as_note_create
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      twitter_handle_id = get_twitter_handle.twitter_user_id
      params_hash = {
        body: Faker::Lorem.paragraph,
        notify_emails: [Agent.first.user.email],
        private: true,
        source: 5,
        import_id: 1,
        source_additional_info: {
          twitter: {
            tweet_id: 123_123,
            tweet_type: 'dm',
            support_handle_id: twitter_handle_id,
            stream_id: 3232
          }
        }
      }
      post :create, construct_params({ id: ticket.display_id }, params_hash)
      assert_response 201
      t = Helpdesk::Note.last
      match_json(show_note_pattern(params_hash, Helpdesk::Note.last))
    ensure
      CustomRequestStore.store[:channel_api_request] = false
      @channel_v2_api = false
    end

    def test_twitter_mention_as_note_create
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      twitter_handle_id = get_twitter_handle.twitter_user_id
      params_hash = {
        body: Faker::Lorem.paragraph,
        notify_emails: [Agent.first.user.email],
        private: true,
        source: 5,
        import_id: 1,
        source_additional_info: {
          twitter: {
            tweet_id: 123_124,
            tweet_type: 'mention',
            support_handle_id: twitter_handle_id,
            stream_id: 3232
          }
        }
      }
      post :create, construct_params({ id: ticket.display_id }, params_hash)
      assert_response 201
      t = Helpdesk::Note.last
      match_json(show_note_pattern(params_hash, Helpdesk::Note.last))
    ensure
      CustomRequestStore.store[:channel_api_request] = false
      @channel_v2_api = false
    end

    def test_twitter_note_create_with_invalid_twitter_handle_id
      CustomRequestStore.store[:channel_api_request] = true
      twitter_handle_id = Faker::Number.number(3).to_i
      params_hash = {
        body: Faker::Lorem.paragraph,
        notify_emails: [Agent.first.user.email],
        private: true,
        source: 5,
        import_id: 1,
        source_additional_info: {
          twitter: {
            tweet_id: 123_124,
            tweet_type: 'mention',
            support_handle_id: twitter_handle_id,
            stream_id: 3232
          }
        }
      }
      post :create, construct_params({ id: ticket.display_id }, params_hash)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:twitter_handle_id,
                                          :invalid_twitter_handle , code: 'invalid_value'))
      match_json(pattern)
    ensure
      CustomRequestStore.store[:channel_api_request] = false
    end

    def test_ticket_conversation_with_unrestricted_tweet_content_channel_api
      Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      @twitter_handle = get_twitter_handle
      @default_stream = @twitter_handle.default_stream
      ticket = create_twitter_ticket(tweet_type: 'mention')
      with_twitter_update_stubbed do
        create_twitter_note(ticket, 'mention')
      end
      get :ticket_conversations, controller_params(id: ticket.display_id)
      result_pattern = []
      ticket.notes.visible.exclude_source('meta').each do |n|
        result_pattern << index_note_pattern(n)
      end
      assert_response 200
      match_json(result_pattern)
    ensure
      ticket.destroy
      Account.any_instance.unstub(:twitter_api_compliance_enabled?)
      CustomRequestStore.store[:channel_api_request] = false
      @channel_v2_api = false
    end

    def test_ticket_conversation_with_unrestricted_twitter_dm_content_channel_api
      Account.any_instance.stubs(:twitter_api_compliance_enabled?).returns(true)
      CustomRequestStore.store[:channel_api_request] = true
      @channel_v2_api = true
      @twitter_handle = get_twitter_handle
      @default_stream = @twitter_handle.default_stream
      ticket = create_twitter_ticket(tweet_type: 'dm')
      with_twitter_update_stubbed do
        create_twitter_note(ticket, 'dm')
      end
      get :ticket_conversations, controller_params(id: ticket.display_id)
      result_pattern = []
      ticket.notes.visible.exclude_source('meta').each do |n|
        result_pattern << index_note_pattern(n)
      end
      assert_response 200
      match_json(result_pattern)
    ensure
      ticket.destroy
      Account.any_instance.unstub(:twitter_api_compliance_enabled?)
      CustomRequestStore.store[:channel_api_request] = false
      @channel_v2_api = false
    end

    def test_notes_resync_with_no_source
      remove_others_redis_key(resync_rate_limiter_key(SOURCE))
      args = { meta: { meta_id: 'abc' }, user_ids: [1, 2], ticket_ids: [1, 2], created_at: { 'start' => '"05/01/2020 10:00:00', 'end' => '"05/01/2020 15:00:00' } }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 403
    end

    def test_notes_resync_with_invalid_source
      invalid_source = 'silkroad'
      remove_others_redis_key(resync_rate_limiter_key(invalid_source))
      set_jwt_auth_header(invalid_source)
      args = { meta: { meta_id: 'abc' }, user_ids: [1, 2], ticket_ids: [1, 2], created_at: { 'start' => '"05/01/2020 10:00:00', 'end' => '"05/01/2020 15:00:00' } }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 403
    end

    def test_notes_resync_success
      set_jwt_auth_header(SOURCE)
      job_id = SecureRandom.hex
      request.stubs(:uuid).returns(job_id)
      remove_others_redis_key(resync_rate_limiter_key(SOURCE))
      expected_body = { 'job_id' => job_id }
      args = { meta: { meta_id: 'abc' }, user_ids: [1, 2], ticket_ids: [1, 2], created_at: { 'start' => '2020-05-01 10:00:00', 'end' => '2020-05-02 05:00:00' } }
      post :sync, construct_params({ version: 'channel' }, args)
      response_body = parse_response @response.body
      assert_response 202
      assert_equal expected_body, response_body
    ensure
      request.unstub(:uuid)
    end

    def test_notes_resync_with_worker_limit_reached
      set_jwt_auth_header(SOURCE)
      set_others_redis_key_if_not_present(resync_rate_limiter_key(SOURCE), 5)
      args = { meta: { meta_id: 'abc' }, user_ids: [1, 2] }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 429
    end

    def test_notes_resync_with_no_filters
      set_jwt_auth_header(SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(SOURCE))
      args = { meta: { meta_id: 'abc' } }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:require_filter_params, 'Anyone of the following filter attributes is mandatory: created_at, user_ids, ticket_ids.', code: 'missing_field'))
      match_json(pattern)
    end

    def test_notes_resync_with_end_date_greater_than_start_date
      set_jwt_auth_header(SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(SOURCE))
      args = { meta: { meta_id: 'abc' }, created_at: { 'start' => '2020-05-02 10:00:00', 'end' => '2020-05-01 05:00:00' } }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:created_at, 'Invalid date time range, end time should be greater or equal to the start time.', code: 'invalid_value'))
      match_json(pattern)
    end

    def test_notes_resync_with_invalid_date_type
      set_jwt_auth_header(SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(SOURCE))
      args = { meta: { meta_id: 'abc' }, created_at: { 'start' => '2020-05-02 10:00:00', 'end' => nil } }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern_with_nested_field(:created_at, 'end', 'It should be a/an String', code: 'datatype_mismatch'))
      match_json(pattern)
    end

    def test_notes_resync_with_date_not_parsed
      set_jwt_auth_header(SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(SOURCE))
      args = { meta: { meta_id: 'abc' }, created_at: { 'start' => '2020-05-02 10:00:00', 'end' => 'ABCD' } }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:created_at, 'Value set is of type String.It should be a/an DateTime', code: 'datatype_mismatch'))
      match_json(pattern)
    end

    def test_notes_resync_with_date_range_more_than_two
      set_jwt_auth_header(SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(SOURCE))
      args = { meta: { meta_id: 'abc' }, created_at: { 'start' => '2020-05-01 10:00:00', 'end' => '2020-05-04 05:00:00' } }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:created_at, 'Datetime range can only be a maximum of 2 days', code: 'invalid_value'))
      match_json(pattern)
    end

    def test_notes_resync_with_invalid_array_field
      set_jwt_auth_header(SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(SOURCE))
      args = { meta: { meta_id: 'abc' }, ticket_ids: nil }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:ticket_ids, 'Value set is of type Null.It should be a/an Array', code: 'datatype_mismatch'))
      match_json(pattern)
    end

    def test_notes_resync_with_ticket_ids_as_string
      set_jwt_auth_header(SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(SOURCE))
      args = { meta: { meta_id: 'abc' }, ticket_ids: '10' }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:ticket_ids, 'Value set is of type String.It should be a/an Array', code: 'datatype_mismatch'))
      match_json(pattern)
    end

    def test_notes_resync_with_array_count_exceeding_limit
      set_jwt_auth_header(SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(SOURCE))
      args = { meta: { meta_id: 'abc' }, ticket_ids: [*1..101] }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:ticket_ids, 'Has 101 elements, it can have maximum of 100 elements', code: 'invalid_value'))
      match_json(pattern)
    end

    def test_notes_resync_with_invalid_meta
      set_jwt_auth_header(SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(SOURCE))
      args = { meta: nil, ticket_ids: [1] }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:meta, "can't be blank", code: 'invalid_value'))
      match_json(pattern)
    end

    def test_notes_resync_with_invalid_primary_key_offset
      set_jwt_auth_header(SOURCE)
      remove_others_redis_key(resync_rate_limiter_key(SOURCE))
      args = { meta: { meta_id: 'abc' }, ticket_ids: [1], primary_key_offset: 'id' }
      post :sync, construct_params({ version: 'channel' }, args)
      assert_response 400
      pattern = validation_error_pattern(bad_request_error_pattern(:primary_key_offset, 'Value set is of type String.It should be a/an Positive Integer', code: 'datatype_mismatch'))
      match_json(pattern)
    end
  end
end
