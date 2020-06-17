require_relative '../../../test_helper'
['social_tickets_creation_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module Channel::V2
  class ConversationsControllerTest < ActionController::TestCase
    include ConversationsTestHelper
    include SocialTicketsCreationHelper
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
  end
end
