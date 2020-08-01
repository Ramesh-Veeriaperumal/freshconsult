require_relative '../../test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'api', 'helpers', 'advanced_scope_test_helper.rb')

Sidekiq::Testing.fake!
['canned_responses_helper.rb', 'group_helper.rb', 'social_tickets_creation_helper.rb', 'twitter_helper.rb', 'dynamo_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module Ember
  class ConversationsControllerTest < ActionController::TestCase
    include ApiTicketsTestHelper
    include ConversationsTestHelper
    include AttachmentsTestHelper
    include GroupHelper
    include CannedResponsesHelper
    include SocialTestHelper
    include SocialTicketsCreationHelper
    include TwitterHelper
    include DynamoHelper
    include SurveysTestHelper
    include AwsTestHelper
    include ArchiveTicketTestHelper
    include Redis::UndoSendRedis
    include Redis::RedisKeys
    include Redis::OthersRedis
    include Redis::TicketsRedis
    include PrivilegesHelper
    include AdvancedScopeTestHelper

    BULK_ATTACHMENT_CREATE_COUNT = 2
    BULK_NOTE_CREATE_COUNT       = 2
    ARCHIVE_DAYS = 120
    TICKET_UPDATED_DATE = 150.days.ago

    def setup
      super
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      Account.current.features.es_v2_writes.destroy
      Account.find(Account.current.id).make_current
      Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
      Social::CustomTwitterWorker.stubs(:perform_async).returns(true)
      @twitter_handle = get_twitter_handle
      @default_stream = @twitter_handle.default_stream
      Account.current.launch(:skip_posting_to_fb)
      # Deleting ticket fields starting with number (which is not allowed in our product)
      Account.current.ticket_fields.custom_fields.each do |tf|
        tf.destroy if (tf.name =~ /^[0-9]/).try(:zero?)
      end
    end

    def teardown
      super
      MixpanelWrapper.unstub(:send_to_mixpanel)
      Social::CustomTwitterWorker.unstub(:perform_async)
      Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      Account.current.rollback(:skip_posting_to_fb)
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

    def account
      @account ||= create_test_account
    end

    def note
      Helpdesk::Note.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['note'], deleted: false).first || create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
    end

    def create_note_params_hash
      {
        body: Faker::Lorem.paragraph,
        notify_emails: Account.current.agents_details_from_cache.sample(2).map(&:email),
        private: true
      }
    end

    def reply_note_params_hash
      body = Faker::Lorem.paragraph
      email = [Faker::Internet.email, Faker::Internet.email, "\"#{Faker::Name.name}\" <#{Faker::Internet.email}>"]
      bcc_emails = [Faker::Internet.email, Faker::Internet.email, "\"#{Faker::Name.name}\" <#{Faker::Internet.email}>"]
      email_config = @account.email_configs.where(active: true).first || create_email_config
      { body: body, cc_emails: email, bcc_emails: bcc_emails, from_email: email_config.reply_email }
    end

    def twitter_dm_reply_params_hash
      body = Faker::Lorem.characters(rand(1..140))
      twitter_handle_id = @twitter_handle.id
      tweet_type = 'dm'
      params_hash = { body: body, twitter_handle_id: twitter_handle_id, tweet_type: tweet_type }
      params_hash
    end

    def forward_note_params_hash
      body = Faker::Lorem.paragraph
      to_emails = [Faker::Internet.email, Faker::Internet.email, "\"#{Faker::Name.name}\" <#{Faker::Internet.email}>"]
      cc_emails = [Faker::Internet.email, Faker::Internet.email, "\"#{Faker::Name.name}\" <#{Faker::Internet.email}>"]
      bcc_emails = [Faker::Internet.email, Faker::Internet.email, "\"#{Faker::Name.name}\" <#{Faker::Internet.email}>"]
      email_config = @account.email_configs.where(active: true).first || create_email_config
      params_hash = { body: body, to_emails: to_emails, cc_emails: cc_emails, bcc_emails: bcc_emails, from_email: email_config.reply_email }
      params_hash
    end

    def broadcast_note_params
      body = Faker::Lorem.paragraph
      user_id = @agent.id
      params_hash = { body: body, user_id: user_id }
    end

    def update_note_params_hash
      body = Faker::Lorem.paragraph
      params_hash = { body: body }
      params_hash
    end

    def dalli_client_unstub
      Dalli::Client.any_instance.unstub(:get)
      Dalli::Client.any_instance.unstub(:delete)
      Dalli::Client.any_instance.unstub(:set)
    end

    def dalli_client_stub
      Dalli::Client.any_instance.stubs(:get).returns(nil)
      Dalli::Client.any_instance.stubs(:delete).returns(true)
      Dalli::Client.any_instance.stubs(:set).returns(true)      
    end

    def test_create_with_incorrect_attachment_type
      attachment_ids = %w(A B C)
      params_hash = create_note_params_hash.merge(attachment_ids: attachment_ids)
      post :create, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      match_json([bad_request_error_pattern(:attachment_ids, :array_datatype_mismatch, expected_data_type: 'Positive Integer')])
      assert_response 400
    end

    def test_create_with_invalid_attachment_ids
      attachment_ids = []
      attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      invalid_ids = [attachment_ids.last + 10, attachment_ids.last + 20]
      params_hash = create_note_params_hash.merge(attachment_ids: (attachment_ids | invalid_ids))
      post :create, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      match_json([bad_request_error_pattern(:attachment_ids, :invalid_list, list: invalid_ids.join(', '))])
      assert_response 400
    end

    def test_create_with_invalid_attachment_size
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params_hash = create_note_params_hash.merge(attachment_ids: [attachment_id])
      invalid_attachment_limit = @account.attachment_limit + 1
      Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(invalid_attachment_limit.megabytes)
      post :create, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      Helpdesk::Attachment.any_instance.unstub(:content_file_size)
      match_json([bad_request_error_pattern(:attachment_ids, :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{invalid_attachment_limit} MB")])
      assert_response 400
    end

    def test_create_with_attachment_ids
      attachment_ids = []
      BULK_ATTACHMENT_CREATE_COUNT.times do
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      end
      params_hash = create_note_params_hash.merge(attachment_ids: attachment_ids)
      post :create, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      match_json(private_note_pattern(params_hash, Helpdesk::Note.last))
      match_json(private_note_pattern({}, Helpdesk::Note.last))
      assert Helpdesk::Note.last.attachments.size == attachment_ids.size
    end

    def test_create_with_inline_attachment_ids
      inline_attachment_ids = []
      BULK_ATTACHMENT_CREATE_COUNT.times do
        inline_attachment_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
      end
      params_hash = create_note_params_hash.merge(inline_attachment_ids: inline_attachment_ids)
      post :create, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, note))
      match_json(private_note_pattern({}, note))
      assert_equal inline_attachment_ids.size, note.inline_attachments.size
    end

    def test_create_with_invalid_inline_attachment_ids
      inline_attachment_ids, valid_ids, invalid_ids = [], [], []
      BULK_ATTACHMENT_CREATE_COUNT.times do
        invalid_ids << create_attachment(attachable_type: 'Forums Image Upload').id
      end
      invalid_ids << 0
      BULK_ATTACHMENT_CREATE_COUNT.times do
        valid_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
      end
      inline_attachment_ids = invalid_ids + valid_ids
      params_hash = create_note_params_hash.merge(inline_attachment_ids: inline_attachment_ids)
      post :create, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('inline_attachment_ids', :invalid_inline_attachments_list, invalid_ids: invalid_ids.join(', '))])
    end

    def test_tweet_email_reply
      @account.launch(:twitter_public_api)
      t = create_ticket(source: 5)
      params_hash = reply_note_params_hash.merge(full_text: Faker::Lorem.paragraph(10))
      post :reply, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 201
    ensure
      @account.rollback(:twitter_public_api)
    end

    def test_fb_email_reply
      @account.launch(:facebook_public_api)
      t = create_ticket(source: 6)
      params_hash = reply_note_params_hash.merge(full_text: Faker::Lorem.paragraph(10))
      post :reply, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 201
    ensure
      @account.rollback(:facebook_public_api)
    end

    def test_create_with_attachment_and_attachment_ids
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      file1 = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
      file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
      attachments = [file1, file2]
      params_hash = create_note_params_hash.merge(attachment_ids: [attachment_id], attachments: attachments)
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data'
      post :create, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 201
      match_json(private_note_pattern(params_hash, Helpdesk::Note.last))
      match_json(private_note_pattern({}, Helpdesk::Note.last))
      assert Helpdesk::Note.last.attachments.size == (attachments.size + 1)
    end

    def test_create_with_cloud_files_upload
      cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20 }]
      params = create_note_params_hash.merge(cloud_files: cloud_file_params)
      post :create, construct_params({ version: 'private', id: ticket.display_id }, params)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params, latest_note))
      match_json(private_note_pattern({}, latest_note))
      assert latest_note.cloud_files.count == 1
    end

    def test_create_with_shared_attachments
      canned_response = create_response(
        title: Faker::Lorem.sentence,
        content_html: Faker::Lorem.paragraph,
        visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
        attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) }
      )
      params = create_note_params_hash.merge(attachment_ids: canned_response.shared_attachments.map(&:attachment_id))
      stub_attachment_to_io do
        post :create, construct_params({ version: 'private', id: create_ticket.display_id }, params)
      end
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params, latest_note))
      match_json(private_note_pattern({}, latest_note))
      assert latest_note.attachments.count == 1
    end

    def test_create_with_spam_ticket
      t = create_ticket(spam: true)
      post :create, construct_params({ version: 'private', id: t.display_id }, create_note_params_hash)
      assert_response 404
    ensure
      t.update_attributes(spam: false)
    end

    def test_reply_with_full_text
      params_hash = reply_note_params_hash.merge(full_text: Faker::Lorem.paragraph(10))
      post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
    end

    def test_reply_with_ticket_params
      ::Tickets::SendAndSetWorker.clear
      params_hash = reply_note_params_hash.merge('ticket' => { 'priority' => 3, 'status' => 3, 'source' => 5, 'type' => 'Problem' })
      post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      assert ::Tickets::SendAndSetWorker.jobs.size == 1
      assert JSON.parse(response.body)['ticket'].present?
      assert JSON.parse(response.body)['ticket']['priority'] == 3
      assert JSON.parse(response.body)['ticket']['status'] == 3
      assert JSON.parse(response.body)['ticket']['source'] == 5
      assert JSON.parse(response.body)['ticket']['type'] == 'Problem'
      ticket.destroy
    end

    def test_reply_with_ticket_params_and_attachment
      ::Tickets::SendAndSetWorker.clear
      conversation = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
      attachment = create_attachment(attachable_type: 'Helpdesk::Note', attachable_id: conversation.id)
      params_hash = reply_note_params_hash.merge(attachment_ids: [attachment.id])
      ticket_params = { ticket: { priority: 3, status: 3, source: 5, type: 'Problem' } }
      params_hash.merge!(ticket_params)
      stub_attachment_to_io do
        post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      end
      assert_response 201
      assert_equal ::Tickets::SendAndSetWorker.jobs.size, 1
      note_attachment = Helpdesk::Note.last.attachments.first
      refute_equal note_attachment.id, attachment.id
      assert_equal attachment_content_hash(note_attachment), attachment_content_hash(attachment)
      ticket.destroy
    end

    def test_reply_without_ticket_params
      ::Tickets::SendAndSetWorker.clear
      params_hash = reply_note_params_hash
      post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      assert ::Tickets::SendAndSetWorker.jobs.size.zero?
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
    end

    def test_reply_with_undo_send
      @account.add_feature(:undo_send)
      user = other_user
      User.any_instance.stubs(:enabled_undo_send?).returns(true)
      user.preferences[:agent_preferences][:undo_send] = true
      params_hash = reply_note_params_hash
      params_hash[:user_id] = user.id
      Sidekiq::Testing.inline! do
        post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      end
      assert_response 201
      user.preferences[:agent_preferences][:undo_send] = false
      @account.revoke_feature(:undo_send)
      User.any_instance.unstub(:enabled_undo_send?)
    end

    def test_reply_with_ticket_attribtutes_and_undo_send
      ::Tickets::SendAndSetWorker.clear
      @account.add_feature(:undo_send)
      user = other_user
      User.any_instance.stubs(:enabled_undo_send?).returns(true)
      user.preferences[:agent_preferences][:undo_send] = true
      params_hash = reply_note_params_hash.merge('ticket' => { 'priority' => 3, 'status' => 3, 'source' => 5, 'type' => 'Problem' })
      params_hash[:user_id] = user.id
      # Sidekiq::Testing.inline! do
        post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      # end
      assert_response 201
      assert_equal ::Tickets::SendAndSetWorker.jobs.size, 1
      user.preferences[:agent_preferences][:undo_send] = false
      assert JSON.parse(response.body)['ticket'].present?
      assert JSON.parse(response.body)['ticket']['priority'] == 3
      assert JSON.parse(response.body)['ticket']['status'] == 3
      assert JSON.parse(response.body)['ticket']['source'] == 5
      assert JSON.parse(response.body)['ticket']['type'] == 'Problem'
      @account.revoke_feature(:undo_send)
      User.any_instance.unstub(:enabled_undo_send?)
    end

    def test_reply_with_undo_send_with_variable_timer_value
      key = UNDO_SEND_TIMER % { :account_id => Account.current.id }
      set_tickets_redis_key(key, "20")
      @account.add_feature(:undo_send)
      user = other_user
      User.any_instance.stubs(:enabled_undo_send?).returns(true)
      user.preferences[:agent_preferences][:undo_send] = true
      params_hash = reply_note_params_hash
      params_hash[:user_id] = user.id
      Sidekiq::Testing.inline! do
        post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      end
      assert_equal 20.seconds + UNDO_SEND_TIMER_BUFFER, undo_send_timer_value
      assert_response 201
      user.preferences[:agent_preferences][:undo_send] = false
      @account.revoke_feature(:undo_send)
      remove_tickets_redis_key(key)
      User.any_instance.unstub(:enabled_undo_send?)
    end

    def test_dummy_id_generated_with_undo_send
      @account.add_feature(:undo_send)
      user = other_user
      user.preferences[:agent_preferences][:undo_send] = true
      params_hash = reply_note_params_hash
      old_count = Helpdesk::Note.count
      params_hash[:user_id] = user.id
      post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      new_count = Helpdesk::Note.count
      assert_response 201
      assert_equal old_count + 1, new_count
      user.preferences[:agent_preferences][:undo_send] = false
      @account.revoke_feature(:undo_send)
    end

    def test_reply_with_undo_send_with_previous_note
      @account.add_feature(:undo_send)
      user = other_user
      user.preferences[:agent_preferences][:undo_send] = true
      params_hash = reply_note_params_hash
      params_hash[:user_id] = user.id
      post :reply, construct_params({ version: 'private', id: ticket.display_id, last_note_id: 15 }, params_hash)
      assert_response 201
      user.preferences[:agent_preferences][:undo_send] = false
      @account.revoke_feature(:undo_send)
    end

    def test_reply_being_undone
      @account.add_feature(:undo_send)
      user = other_user
      User.any_instance.stubs(:enabled_undo_send?).returns(true)
      user.preferences[:agent_preferences][:undo_send] = true
      put :undo_send, version: 'private', id: ticket.display_id, created_at: Time.now.utc
      assert_response 204
      user.preferences[:agent_preferences][:undo_send] = false
      @account.revoke_feature(:undo_send)
    end

    def test_reply_template_after_undo_no_quoted_text
      @account.add_feature(:undo_send)
      remove_wrap_params
      t = create_ticket
      time = Time.now.utc
      note_body = {}
      note_body['body_html'] = 'Body html'
      note_body['full_text_html'] = 'Body html'
      set_body_data(1, t.display_id, time, note_body)
      notification_template = '<div>{{ticket.id}}</div>'
      Agent.any_instance.stubs(:signature_value).returns('')
      EmailNotification.any_instance.stubs(:get_reply_template).returns(notification_template)
      bcc_emails = "#{Faker::Internet.email};#{Faker::Internet.email}"
      Account.any_instance.stubs(:bcc_email).returns(bcc_emails)
      post :reply_template, construct_params({ version: 'private', id: t.display_id, body: 'Undo', attachments: [], inline: [], time: time }, false)
      quoted_text = JSON.parse(response.body)['quoted_text']
      assert_response 200
      assert_equal nil, quoted_text
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_reply_template)
    ensure
      Account.any_instance.unstub(:bcc_email)
      @account.revoke_feature(:undo_send)
    end

    def test_quoted_text_reply_template_after_undo
      @account.add_feature(:undo_send)
      remove_wrap_params
      t = create_ticket
      time = Time.now.utc
      note_body = {}
      note_body['body_html'] = 'Body html'
      note_body['full_text_html'] = 'Body html <div class="freshdesk_quote">" hello "</div class="freshdesk_quote">'
      set_body_data(1, t.display_id, time, note_body)
      notification_template = '<div>{{ticket.id}}</div>'
      Agent.any_instance.stubs(:signature_value).returns('')
      EmailNotification.any_instance.stubs(:get_reply_template).returns(notification_template)
      Ember::ConversationsController.any_instance.stubs(:get_quoted_content).returns(note_body['full_text_html'])
      bcc_emails = "#{Faker::Internet.email};#{Faker::Internet.email}"
      Account.any_instance.stubs(:bcc_email).returns(bcc_emails)
      post :reply_template, construct_params({ version: 'private', id: t.display_id, body: 'Undo', attachments: [], inline: [], time: time }, false)
      quoted_text = JSON.parse(response.body)['quoted_text']
      assert_response 200
      assert_equal '<div class="freshdesk_quote">" hello "</div class="freshdesk_quote">', quoted_text
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_reply_template)
    ensure
      Account.any_instance.unstub(:bcc_email)
      @account.revoke_feature(:undo_send)
    end

    def test_reply_template_after_undo_with_attachments
      @account.add_feature(:undo_send)
      remove_wrap_params
      t = create_ticket
      notification_template = '<div>{{ticket.id}}</div>'
      Agent.any_instance.stubs(:signature_value).returns('')
      EmailNotification.any_instance.stubs(:get_reply_template).returns(notification_template)
      bcc_emails = "#{Faker::Internet.email};#{Faker::Internet.email}"
      Account.any_instance.stubs(:bcc_email).returns(bcc_emails)
      post :reply_template, construct_params({ version: 'private', id: t.display_id, body: 'Undo', attachments: [{ id: '44' }, { id: '55' }], inline: [1, 2] }, false)
      assert_response 200
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_reply_template)
    ensure
      Account.any_instance.unstub(:bcc_email)
      @account.revoke_feature(:undo_send)
    end

    def test_reply_to_tictet_sender_email_undo_send_enabled
      @account.add_feature(:undo_send)
      user = add_user_with_multiple_emails(@account, 2)
      secondary_email = user.user_emails.first.email
      new_ticket = create_ticket(requester_id: user.id)
      new_ticket.reload
      ticket.schema_less_ticket.update_attribute(:sender_email, secondary_email)
      User.any_instance.stubs(:enabled_undo_send?).returns(true)
      params_hash = reply_note_params_hash
      params_hash[:user_id] = user.id
      Sidekiq::Testing.inline! do
        post :reply, construct_params({ version: 'private', id: new_ticket.display_id }, params_hash)
      end
      assert_response 201
      response = parse_response @response.body
      assert_equal response['to_emails'], [secondary_email]
      assert_include new_ticket.notes.last.schema_less_note.to_emails, secondary_email
    ensure
      new_ticket.destroy
      user.destroy
      @account.revoke_feature(:undo_send)
      User.any_instance.unstub(:enabled_undo_send?)
    end

    def test_reply_without_from_email
      # Without personalized_email_replies
      @account.features.personalized_email_replies.destroy
      @account.reload
      Account.current.reload

      params_hash = reply_note_params_hash.merge(full_text: Faker::Lorem.paragraph(10))
      params_hash.delete(:from_email)
      post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      assert_equal ticket.selected_reply_email, latest_note.from_email
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
    end

    def test_reply_without_from_email_and_personalized_replies
      # WITH personalized_email_replies
      @account.features.personalized_email_replies.create
      @account.reload

      Account.current.reload
      params_hash = reply_note_params_hash
      params_hash.delete(:from_email)
      post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last

      assert_equal ticket.friendly_reply_email_personalize(@agent.name), latest_note.from_email
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
    end

    def test_reply_with_invalid_attachment_ids
      attachment_ids = []
      attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      invalid_ids = [attachment_ids.last + 10, attachment_ids.last + 20]
      params_hash = reply_note_params_hash.merge(attachment_ids: (attachment_ids | invalid_ids))
      post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      match_json([bad_request_error_pattern(:attachment_ids, :invalid_list, list: invalid_ids.join(', '))])
      assert_response 400
    end

    def test_reply_with_invalid_attachment_size
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params_hash = reply_note_params_hash.merge(attachment_ids: [attachment_id])
      invalid_attachment_limit = @account.attachment_limit + 3
      Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(invalid_attachment_limit.megabytes)
      post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      Helpdesk::Attachment.any_instance.unstub(:content_file_size)
      match_json([bad_request_error_pattern(:attachment_ids, :invalid_size,
        max_size: "#{@account.attachment_limit} MB", current_size: "#{invalid_attachment_limit} MB")])
      assert_response 400
    end

    def test_reply_with_attachment_ids
      attachment_ids = []
      BULK_ATTACHMENT_CREATE_COUNT.times do
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      end
      params_hash = reply_note_params_hash.merge(attachment_ids: attachment_ids, user_id: @agent.id)
      post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      match_json(private_note_pattern(params_hash, Helpdesk::Note.last))
      match_json(private_note_pattern({}, Helpdesk::Note.last))
      assert Helpdesk::Note.last.attachments.size == attachment_ids.size
    end

    def test_reply_with_child_description_attachment_ids
      Account.any_instance.stubs(:parent_child_tickets_enabled?).returns(true)
      child_attachment_ids = []
      create_parent_child_tickets
      child_attachment_ids << create_attachment(attachable_type: 'Helpdesk::Ticket', attachable_id: @child_ticket.id).id
      params_hash = reply_note_params_hash.merge(attachment_ids: child_attachment_ids, user_id: @agent.id)
      stub_attachment_to_io do
        post :reply, construct_params({ version: 'private', id: @parent_ticket.display_id }, params_hash)
      end
      assert_response 201
      match_json(private_note_pattern(params_hash, @account.notes.last))
      match_json(private_note_pattern({}, @account.notes.last))
      assert @account.notes.last.attachments.size == child_attachment_ids.size
      Account.any_instance.unstub(:parent_child_tickets_enabled?)
    end

    def test_reply_with_inline_attachment_ids
      inline_attachment_ids = []
      BULK_ATTACHMENT_CREATE_COUNT.times do
        inline_attachment_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
      end
      params_hash = reply_note_params_hash.merge(inline_attachment_ids: inline_attachment_ids, user_id: @agent.id)
      post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, note))
      match_json(private_note_pattern({}, note))
      assert_equal inline_attachment_ids.size, note.inline_attachments.size 
    end

    def test_reply_with_invalid_inline_attachment_ids
      inline_attachment_ids, valid_ids, invalid_ids = [], [], []
      BULK_ATTACHMENT_CREATE_COUNT.times do
        invalid_ids << create_attachment(attachable_type: 'Forums Image Upload').id
      end
      invalid_ids << 0
      BULK_ATTACHMENT_CREATE_COUNT.times do
        valid_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
      end
      inline_attachment_ids = invalid_ids + valid_ids
      params_hash = reply_note_params_hash.merge(inline_attachment_ids: inline_attachment_ids, user_id: @agent.id)
      post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('inline_attachment_ids', :invalid_inline_attachments_list, invalid_ids: invalid_ids.join(', '))])
    end

    def test_reply_with_attachment_and_attachment_ids
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      file1 = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
      file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
      attachments = [file1, file2]
      params_hash = reply_note_params_hash.merge(attachment_ids: [attachment_id], attachments: attachments)
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data'
      post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 201
      match_json(private_note_pattern(params_hash, Helpdesk::Note.last))
      match_json(private_note_pattern({}, Helpdesk::Note.last))
      assert Helpdesk::Note.last.attachments.size == (attachments.size + 1)
    end

    def test_reply_with_attachment_id_name_in_unicode
      unicode_ticket = ticket
      file = fixture_file_upload('files/Квитанция.log', 'text/plain', :binary)
      attachment_id = create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params_hash = reply_note_params_hash.merge(attachment_ids: [attachment_id])
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data'
      post :reply, construct_params({ version: 'private', id: unicode_ticket.display_id }, params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 201
      assert Helpdesk::Note.last.attachments.first.content_file_name == 'Квитанция.log'
    end

    def test_reply_with_cloud_files_upload
      cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20 }]
      params = reply_note_params_hash.merge(cloud_files: cloud_file_params)
      post :reply, construct_params({ version: 'private', id: ticket.display_id }, params)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params, latest_note))
      match_json(private_note_pattern({}, latest_note))
      assert latest_note.cloud_files.count == 1
    end

    def test_reply_with_shared_attachments
      canned_response = create_response(
        title: Faker::Lorem.sentence,
        content_html: Faker::Lorem.paragraph,
        visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
        attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) }
      )
      params = reply_note_params_hash.merge(attachment_ids: canned_response.shared_attachments.map(&:attachment_id))
      stub_attachment_to_io do
        post :reply, construct_params({ version: 'private', id: create_ticket.display_id }, params)
      end
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params, latest_note))
      match_json(private_note_pattern({}, latest_note))
      assert latest_note.attachments.count == 1
    end

    def test_reply_with_inapplicable_survey_option
      survey = Account.current.survey
      survey.send_while = rand(1..3)
      survey.save
      t = create_ticket
      params_hash = reply_note_params_hash.merge(send_survey: true)
      post :reply, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern(:send_survey, :should_be_blank)])
    end

    def test_reply_without_survey_link
      survey = Account.current.survey
      survey.send_while = 4
      survey.save
      t = create_ticket
      params_hash = reply_note_params_hash.merge(send_survey: false)
      post :reply, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 201
      match_json(private_note_pattern(params_hash, Helpdesk::Note.last))
      match_json(private_note_pattern({}, Helpdesk::Note.last))
    end

    def test_reply_with_survey_link
      survey = Account.current.survey
      survey.send_while = 4
      survey.save
      t = create_ticket
      params_hash = reply_note_params_hash.merge(send_survey: true)
      post :reply, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 201
      match_json(private_note_pattern(params_hash, Helpdesk::Note.last))
      match_json(private_note_pattern({}, Helpdesk::Note.last))
    end

    def test_reply_to_spammed_ticket
      t = create_ticket(spam: true)
      post :reply, construct_params({ version: 'private', id: t.display_id }, reply_note_params_hash)
      assert_response 404
    ensure
      t.update_attributes(spam: false)
    end

    def test_reply_with_user_id_invalid_privilege
      t = create_ticket
      params_hash = reply_note_params_hash.merge(user_id: other_user.id)
      @controller.stubs(:is_allowed_to_assume?).returns(false)
      post :reply, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 403
      match_json(request_error_pattern('invalid_user', id: other_user.id, name: other_user.name))
    ensure
      @controller.unstub(:is_allowed_to_assume?)
    end

    def test_ticket_conversations_with_fone_call
      # while creating freshfone account during tests MixpanelWrapper was throwing error, so stubing that
      Account.any_instance.stubs(:freshfone_enabled?).returns(true)
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      ticket = new_ticket_from_call
      remove_wrap_params
      assert ticket.notes.all.map { |n| n.freshfone_call.present? || nil }.compact.present?
      get :ticket_conversations, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 200
      match_json(conversations_pattern(ticket))
    ensure
      MixpanelWrapper.unstub(:send_to_mixpanel)
      Account.any_instance.unstub(:freshfone_enabled?)
    end

    def test_ticket_conversations_with_freshcaller_call
      # while creating freshcaller account during tests MixpanelWrapper was throwing error, so stubing that
      Account.any_instance.stubs(:freshcaller_enabled?).returns(true)
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      ticket = new_ticket_from_freshcaller_call
      remove_wrap_params
      assert ticket.notes.all.map { |n| n.freshcaller_call.present? || nil }.compact.present?
      get :ticket_conversations, construct_params({ version: 'private', id: ticket.display_id }, false)
      ticket.notes.reload
      assert_response 200
      match_json(conversations_pattern_freshcaller(ticket))
    ensure
      MixpanelWrapper.unstub(:send_to_mixpanel)
      Account.any_instance.unstub(:freshcaller_enabled?)
    end

    def test_ticket_conversations_on_spammed_ticket
      t = create_ticket(spam: true)
      get :ticket_conversations, controller_params(version: 'private', id: t.display_id)
      assert_response 200
      match_json(conversations_pattern(t))
    ensure
      t.update_attributes(spam: false)
    end

    def test_facebook_reply_without_params
      ticket = create_ticket_from_fb_post
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, {})
      assert_response 400
      match_json(
        [
          bad_request_error_pattern('body', :missing_field, code: :missing_field),
          bad_request_error_pattern('msg_type', :datatype_mismatch, code: :missing_field, expected_data_type: String)
        ]
      )
    end

    def test_facebook_reply_with_invalid_ticket
      ticket = create_ticket
      params_hash = { body: Faker::Lorem.paragraph, msg_type: 'post' }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('ticket_id', :not_a_facebook_ticket)])
    end

    def test_facebook_reply_with_invalid_note_id
      ticket = create_ticket_from_fb_post
      invalid_id = (Helpdesk::Note.last.try(:id) || 0) + 10
      params_hash = { body: Faker::Lorem.paragraph, note_id: invalid_id, msg_type: 'post' }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('note_id', :absent_in_db, resource: :note, attribute: :note_id)])
    end

    def test_facebook_reply_failure
      Account.current.rollback(:skip_posting_to_fb)
      ticket = create_ticket_from_fb_post
      @controller.stubs(:send_reply_to_fb).returns(:failure)
      params_hash = { body: Faker::Lorem.paragraph, msg_type: 'post' }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('body', :unable_to_perform)])
      @controller.unstub(:send_reply_to_fb)    
    end

   def test_facebook_reply_to_fb_dm_ticket_when_user_blocked
      Account.current.rollback(:skip_posting_to_fb)
      ticket = create_ticket_from_fb_direct_message
      @controller.stubs(:send_reply_to_fb).returns(:fb_user_blocked)
      params_hash = { body: Faker::Lorem.paragraph, msg_type: 'dm' }
      res = post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('body', :facebook_user_blocked)])
      @controller.unstub(:send_reply_to_fb)
    end

    def test_facebook_reply_to_fb_post_ticket
      Account.current.rollback(:skip_posting_to_fb)
      ticket = create_ticket_from_fb_post
      put_comment_id = "#{(Time.now.ago(2.minutes).utc.to_f * 100_000).to_i}_#{(Time.now.ago(6.minutes).utc.to_f * 100_000).to_i}"
      sample_put_comment = { 'id' => put_comment_id }
      Koala::Facebook::API.any_instance.stubs(:put_comment).returns(sample_put_comment)
      params_hash = { body: Faker::Lorem.paragraph, msg_type: 'post' }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      Koala::Facebook::API.any_instance.unstub(:put_comment)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
    end

    def test_facebook_reply_to_fb_comment_note
      Account.current.rollback(:skip_posting_to_fb)
      ticket = create_ticket_from_fb_post(true)
      put_comment_id = "#{(Time.now.ago(2.minutes).utc.to_f * 100_000).to_i}_#{(Time.now.ago(6.minutes).utc.to_f * 100_000).to_i}"
      sample_put_comment = { 'id' => put_comment_id }
      fb_comment_note = ticket.notes.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['facebook']).first
      Koala::Facebook::API.any_instance.stubs(:put_comment).returns(sample_put_comment)
      params_hash = { body: Faker::Lorem.paragraph, note_id: fb_comment_note.id, msg_type: 'post' }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      Koala::Facebook::API.any_instance.unstub(:put_comment)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
    end

    def test_facebook_reply_to_fb_direct_message_ticket
      Account.current.rollback(:skip_posting_to_fb)
      ticket = create_ticket_from_fb_direct_message
      sample_reply_dm = { 'id' => Time.now.utc.to_i + 5 }
      Koala::Facebook::API.any_instance.stubs(:put_object).returns(sample_reply_dm)
      params_hash = { body: Faker::Lorem.paragraph, msg_type: 'dm' }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      Koala::Facebook::API.any_instance.unstub(:put_object)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
    end

    def test_facebook_reply_with_survey_to_fb_direct_message_ticket
      skip_posting_to_fb_launched = Account.current.launched?(:skip_posting_to_fb)
      Account.current.rollback(:skip_posting_to_fb)
      Account.any_instance.stubs(:csat_for_social_surveymonkey_enabled?).returns(true)
      Social::FacebookSurveyWorker.jobs.clear
      ticket = create_ticket_from_fb_direct_message
      sample_reply_dm = { 'id' => Time.now.utc.to_i + 5 }
      Koala::Facebook::API.any_instance.stubs(:put_object).returns(sample_reply_dm)
      params_hash = { body: Faker::Lorem.paragraph, msg_type: 'dm', include_surveymonkey_link: 1 }
      app_config = { inputs: { 'survey_link' => 'https://www.surveymonkey.com/r/NMWK2SF', 'survey_text' => 'Please fill the survey' } }
      app = { id: 1, application_id: 1 }
      app.stubs(:configs).returns(app_config)
      Integrations::SurveyMonkey.stubs(:sm_installed_app).returns(app)
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      response_hash = JSON.parse(response.body)
      args = Social::FacebookSurveyWorker.jobs.last['args'][0]
      args.symbolize_keys!
      assert_equal response_hash['id'], args[:note_id]
      assert_equal response_hash['user_id'], args[:user_id]
      assert_equal ticket.requester.fb_profile_id, args[:page_scope_id]
      url = URI.parse("#{app_config[:inputs]['survey_link']}?c=#{User.current.name}&fd_ticketid=#{ticket.display_id}").to_s
      assert_equal "#{app_config[:inputs]['survey_text']} \n #{url}", args[:survey_dm]
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
    ensure
      Account.current.launch(:skip_posting_to_fb) if skip_posting_to_fb_launched
      Account.any_instance.unstub(:csat_for_social_surveymonkey_enabled)
      Integrations::SurveyMonkey.unstub(:sm_installed_app)
      Koala::Facebook::API.any_instance.unstub(:put_object)
    end

    def test_facebook_reply_to_non_fb_post_note
      ticket = create_ticket_from_fb_direct_message
      fb_dm_note = ticket.notes.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['facebook']).first
      params_hash = { body: Faker::Lorem.paragraph, note_id: fb_dm_note.id, msg_type: 'post' }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('note_id', :unable_to_post_reply)])
    end

    def test_facebook_reply_to_non_commentable_note
      ticket = create_ticket_from_fb_post(true, true)
      fb_comment_note = ticket.notes.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['facebook']).last
      params_hash = { body: Faker::Lorem.paragraph, note_id: fb_comment_note.id, msg_type: 'post' }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('note_id', :unable_to_post_reply)])
    end

    def test_facebook_reply_with_invalid_agent_id
      user = add_new_user(account)
      ticket = create_ticket_from_fb_direct_message
      params_hash = { body: Faker::Lorem.paragraph, agent_id: user.id, msg_type: 'post' }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('agent_id', :absent_in_db, resource: :agent, attribute: :agent_id)])
    end

    def test_facebook_reply_with_valid_agent_id
      Account.current.rollback(:skip_posting_to_fb)
      user = add_test_agent(account, role: account.roles.find_by_name('Agent').id)
      ticket = create_ticket_from_fb_direct_message
      sample_reply_dm = { 'id' => Time.now.utc.to_i + 5 }
      Koala::Facebook::API.any_instance.stubs(:put_object).returns(sample_reply_dm)
      params_hash = { body: Faker::Lorem.paragraph, agent_id: user.id, msg_type: 'post' }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      Koala::Facebook::API.any_instance.unstub(:put_object)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
    end

    def test_facebook_reply_to_spammed_ticket
      ticket = create_ticket_from_fb_direct_message
      ticket.update_attributes(spam: true)
      params_hash = { body: Faker::Lorem.paragraph, msg_type: 'post' }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 404
    ensure
      ticket.update_attributes(spam: false)
    end

    def test_facebook_reauth_required_error
      Account.current.rollback(:skip_posting_to_fb)
      ticket = create_ticket_from_fb_post(true)
      fb_page = ticket.fb_post.facebook_page
      fb_page.reauth_required = true
      fb_page.save
      fb_comment_note = ticket.notes.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['facebook']).first
      put_comment_id = "#{(Time.now.ago(2.minutes).utc.to_f * 100_000).to_i}_#{(Time.now.ago(6.minutes).utc.to_f * 100_000).to_i}"
      sample_put_comment = { 'id' => put_comment_id }
      Koala::Facebook::API.any_instance.stubs(:put_comment).returns(sample_put_comment)
      params_hash = { body: Faker::Lorem.paragraph, note_id: fb_comment_note.id, msg_type: 'post' }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      Koala::Facebook::API.any_instance.unstub(:put_comment)
      assert_response 400
      match_json([bad_request_error_pattern('fb_page_id', :reauthorization_required, app_name: 'Facebook')])
    ensure
      fb_page.reauth_required = false
      fb_page.save
    end

    def test_facebook_reply_without_facebook_page
      Social::FacebookPage.any_instance.stubs(:gateway_facebook_page_mapping_details).returns(nil)
      ticket = create_ticket_from_fb_post(true, true)
      fb_page = ticket.fb_post.facebook_page
      fb_page.destroy
      params_hash = { body: Faker::Lorem.paragraph, msg_type: 'post' }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('fb_page_id', :invalid_facebook_id)])
    end

    def test_facebook_reply_without_msg_type
      ticket = create_ticket_from_fb_post(true, true)
      fb_comment_note = ticket.notes.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['facebook']).first
      params_hash = { body: Faker::Lorem.paragraph, note_id: fb_comment_note.id }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('msg_type', :datatype_mismatch, code: :missing_field, expected_data_type: String)])
    end

    def test_facebook_dm_reply_with_incorrect_msg_type
      ticket = create_ticket_from_fb_post(true, true)
      fb_comment_note = ticket.notes.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['facebook']).first
      params_hash = { body: Faker::Lorem.paragraph, note_id: fb_comment_note.id, msg_type: 'posts' }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('msg_type', :not_included, list: 'dm,post,ad_post')])
    end

    def test_facebook_reply_dm_with_more_than_one_attachment_ids
      ticket = create_ticket_from_fb_post(true, true)
      fb_comment_note = ticket.notes.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['facebook']).first
      params_hash = { body: Faker::Lorem.paragraph, note_id: fb_comment_note.id, msg_type: 'post', attachment_ids: [3, 4] }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('attachment_ids', :too_long, current_count: 2, element_type: :characters, max_count: 1)])
    end

    def test_facebook_reply_dm_success_with_attachemnts
      attachment_ids = []
      file = fixture_file_upload('files/image4kb.png', 'image/png')
      attachment_ids << create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
      ticket = create_ticket_from_fb_direct_message
      sample_reply_dm = { 'id' => Time.now.utc.to_i + 5 }
      Koala::Facebook::API.any_instance.stubs(:put_object).returns(sample_reply_dm)
      params_hash = { msg_type: 'dm', attachment_ids: attachment_ids }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      Koala::Facebook::API.any_instance.unstub(:put_object)
      assert_response 201
      latest_note = Account.current.notes.last
      match_json(private_note_pattern(params_hash, latest_note))
    end

    def test_facebook_reply_dm_failure_with_attachemnts_and_body
      attachment_ids = []
      file = fixture_file_upload('files/image4kb.png', 'image/png')
      attachment_ids << create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
      ticket = create_ticket_from_fb_direct_message
      params_hash = { body: Faker::Lorem.paragraph, msg_type: 'dm', attachment_ids: attachment_ids }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      match_json([bad_request_error_pattern('attachment_ids', :can_have_only_one_field, list: 'body, attachment_ids')])
    end

    # Can be removed once we do a launch all of the facebook outgoing attachments feature
    def test_facebook_reply_to_fb_comment_note_without_attachments
      Account.current.rollback(:skip_posting_to_fb)
      ticket = create_ticket_from_fb_post(true)
      put_comment_id = "#{(Time.now.ago(2.minutes).utc.to_f * 100_000).to_i}_#{(Time.now.ago(6.minutes).utc.to_f * 100_000).to_i}"
      sample_put_comment = { 'id' => put_comment_id }
      fb_comment_note = ticket.notes.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['facebook']).first
      Koala::Facebook::API.any_instance.stubs(:put_comment).returns(sample_put_comment)
      params_hash = { body: Faker::Lorem.paragraph, note_id: fb_comment_note.id, msg_type: 'post' }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      Koala::Facebook::API.any_instance.unstub(:put_comment)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
    end

    def test_facebook_reply_to_fb_comment_with_attachments
      attachment_ids = []
      file = fixture_file_upload('files/image4kb.png', 'image/png')
      attachment_ids << create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
      ticket = create_ticket_from_fb_post(true)
      fb_comment_note = ticket.notes.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['facebook']).first
      params_hash = { body: Faker::Lorem.paragraph, note_id: fb_comment_note.id, msg_type: 'post', attachment_ids: attachment_ids }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Account.current.notes.last
      match_json(private_note_pattern(params_hash, latest_note))
    end

    def test_facebook_reply_post_failure_with_invalid_attachment
      attachment_ids = []
      file = fixture_file_upload('files/attachment.txt', 'text/plain')
      attachment_ids << create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
      ticket = create_ticket_from_fb_post(true)
      params_hash = { body: Faker::Lorem.paragraph, msg_type: 'post', attachment_ids: attachment_ids }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      match_json([bad_request_error_pattern('attachment_ids', :attachment_format_invalid, attachment_formats: ApiConstants::FACEBOOK_ATTACHMENT_CONFIG[:post][:fileTypes].join(', ').to_s)])
    end

    def test_facebook_reply_post_failure_with_invalid_attachment_size
      attachment_ids = []
      file = fixture_file_upload('files/attachment.txt', 'text/plain')
      attachment_ids << create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
      invalid_attachment_limit = @account.attachment_limit + 1
      Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(invalid_attachment_limit.megabytes)
      ticket = create_ticket_from_fb_post(true)
      params_hash = { body: Faker::Lorem.paragraph, msg_type: 'post', attachment_ids: attachment_ids }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      Helpdesk::Attachment.any_instance.unstub(:content_file_size)
      match_json([bad_request_error_pattern('attachment_ids', :file_size_limit_error, file_size: ApiConstants::FACEBOOK_ATTACHMENT_CONFIG[:post][:size])])
    end

    def test_tweet_dm_reply_with_attachment_ids
      attachment_ids = []
      file = fixture_file_upload('files/image4kb.png', 'image/png')
      attachment_ids << create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
      ticket = create_twitter_ticket
      dm_text = Faker::Lorem.paragraphs(5).join[0..500]
      @account = Account.current
      reply_id = get_social_id
      dm_reply_params = { id: reply_id, id_str: reply_id.to_s, recipient_id_str: rand.to_s[2..11], text: dm_text, created_at: Time.zone.now.to_s }
      with_twitter_dm_stubbed(Twitter::DirectMessage.new(dm_reply_params)) do
        params_hash = twitter_dm_reply_params_hash.merge(attachment_ids: attachment_ids)
        post :tweet, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
        assert_response 201
        latest_note = Helpdesk::Note.last
        match_json(private_note_pattern(params_hash, latest_note))
        assert latest_note.attachments.size == attachment_ids.size
      end
      ticket.destroy
    end

    def test_tweet_dm_reply_with_survey
      ticket = create_twitter_ticket
      dm_text = Faker::Lorem.paragraphs(5).join[0..500]
      @account = Account.current
      Social::TwitterSurveyWorker.jobs.clear
      Account.any_instance.stubs(:csat_for_social_surveymonkey_enabled?).returns(true)
      reply_id = get_social_id
      params_hash = twitter_dm_reply_params_hash.merge(include_surveymonkey_link: 1)
      app_config = { inputs: { 'survey_link' => 'https://www.surveymonkey.com/r/NMWK2SF', 'survey_text' => 'Please fill the survey' } }
      app = { id: 1, application_id: 1 }
      app.stubs(:configs).returns(app_config)
      Integrations::SurveyMonkey.stubs(:sm_installed_app).returns(app)
      post :tweet, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      response_hash = JSON.parse(response.body)
      args = Social::TwitterSurveyWorker.jobs.last['args'][0]
      args.symbolize_keys!
      reply_handle = @account.twitter_handles.where(id: params_hash[:twitter_handle_id]).first
      assert_equal response_hash['id'], args[:note_id]
      assert_equal response_hash['user_id'], args[:user_id]
      assert_equal ticket.requester.twitter_id, args[:requester_screen_name]
      assert_equal reply_handle.twitter_user_id, args[:twitter_user_id]
      assert_equal params_hash[:twitter_handle_id], args[:twitter_handle_id]
      assert_equal true, args[:stream_id].present?
      assert_equal 'dm', args[:tweet_type]
      url = URI.parse("#{app_config[:inputs]['survey_link']}?c=#{User.current.name}&fd_ticketid=#{ticket.display_id}").to_s
      assert_equal "#{app_config[:inputs]['survey_text']} \n #{url}", args[:survey_dm]
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
      ticket.destroy
    ensure
      Account.unstub(:csat_for_social_surveymonkey_enabled?)
      Integrations::SurveyMonkey.unstub(:sm_installed_app)
    end

    def test_tweet_reply_without_params
      ticket = create_twitter_ticket
      post :tweet, construct_params({ version: 'private', id: ticket.display_id }, {})
      assert_response 400
      match_json([
                   bad_request_error_pattern('body', :datatype_mismatch, code: :missing_field, expected_data_type: String),
                   bad_request_error_pattern('tweet_type', :datatype_mismatch, code: :missing_field, expected_data_type: String),
                   bad_request_error_pattern('twitter_handle_id', :datatype_mismatch, code: :missing_field, expected_data_type: 'Positive Integer')
                 ])
      ticket.destroy
    end

    def test_tweet_reply_with_invalid_ticket
      ticket = create_ticket
      post :tweet, construct_params({ version: 'private', id: ticket.display_id }, body: Faker::Lorem.sentence[0..130],
                                                                                   tweet_type: 'dm',
                                                                                   twitter_handle_id: get_twitter_handle.id)
      assert_response 400
      match_json([bad_request_error_pattern('ticket_id', :not_a_twitter_ticket)])
    end

    def test_tweet_reply_with_invalid_handle
      ticket = create_twitter_ticket
      post :tweet, construct_params({ version: 'private', id: ticket.display_id }, body: Faker::Lorem.sentence[0..130],
                                    tweet_type: 'dm',
                                    twitter_handle_id: 123)
      assert_response 400
      match_json([bad_request_error_pattern('twitter_handle_id', 'is invalid')])
      ticket.destroy
    end

    def test_tweet_reply_with_requth
      ticket = create_twitter_ticket
      Social::TwitterHandle.any_instance.stubs(:reauth_required?).returns(true)
      post :tweet, construct_params({ version: 'private', id: ticket.display_id }, body: Faker::Lorem.sentence[0..130],
                                    tweet_type: 'dm',
                                    twitter_handle_id: get_twitter_handle.id)
      assert_response 400
      match_json([bad_request_error_pattern('twitter_handle_id', 'requires re-authorization')])
      Social::TwitterHandle.any_instance.stubs(:reauth_required?).returns(false)
      ticket.destroy
    end

    def test_tweet_reply_with_app_blocked
      set_others_redis_key(TWITTER_APP_BLOCKED, true, 5)
      twitter_handle = get_twitter_handle
      ticket = create_twitter_ticket(twitter_handle: twitter_handle)
      post :tweet, construct_params({ version: 'private', id: ticket.display_id }, body: Faker::Lorem.sentence[0..130],
                                    tweet_type: 'dm',
                                    twitter_handle_id: twitter_handle.id)
      assert_response 400
      match_json(validation_error_pattern(bad_request_error_pattern('twitter', :twitter_write_access_blocked)))
      ticket.destroy
    ensure
      remove_others_redis_key TWITTER_APP_BLOCKED
    end

    def test_twitter_reply_to_tweet_ticket
      Sidekiq::Testing.inline! do
        with_twitter_update_stubbed do
          ticket = create_twitter_ticket
          @account = Account.current
          params_hash = {
            body: Faker::Lorem.sentence[0..130],
            tweet_type: 'mention',
            twitter_handle_id: @twitter_handle.id
          }
          post :tweet, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
          assert_response 201
          latest_note = Helpdesk::Note.last
          match_json(private_note_pattern(params_hash, latest_note))
          tweet = latest_note.tweet
          assert_equal tweet.tweet_id < 0, true, 'Tweet id should be less than zero'
          assert_equal tweet.tweet_type, params_hash[:tweet_type]
          assert_equal tweet.stream_id, @twitter_handle.default_stream.id
          ticket.destroy
        end
      end
    end

    def test_twitter_reply_to_tweet_note
      Sidekiq::Testing.inline! do
        with_twitter_update_stubbed do
          ticket = create_twitter_ticket
          @account = Account.current
          params_hash = {
            body: Faker::Lorem.sentence[0..130],
            tweet_type: 'mention',
            twitter_handle_id: @twitter_handle.id
          }
          post :tweet, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
          assert_response 201
          latest_note = Helpdesk::Note.last
          match_json(private_note_pattern(params_hash, latest_note))
          tweet = latest_note.tweet
          assert_equal tweet.tweet_id < 0, true, 'Tweet id should be less than zero'
          assert_equal tweet.tweet_type, params_hash[:tweet_type]
          assert_equal tweet.stream_id, @twitter_handle.default_stream.id
          ticket.destroy
        end
      end
    end

    def test_twitter_reply_to_tweet_ticket_with_attachments
      attachment_ids = []
      file = fixture_file_upload('files/image4kb.png', 'image/png')
      attachment_ids << create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
      ticket = create_twitter_ticket
      @account = Account.current
      params_hash = {
            body: Faker::Lorem.sentence[0..130],
            tweet_type: 'mention',
            twitter_handle_id: @twitter_handle.id,
            attachment_ids: attachment_ids
          }
      Sidekiq::Testing.inline! do
        with_twitter_update_stubbed do
          Twitter::REST::Client.any_instance.expects(:upload).once
          post :tweet, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
          assert_response 201
          latest_note = Helpdesk::Note.last
          match_json(private_note_pattern(params_hash, latest_note))
          file_name = "tempfile-#{@account.id}-#{@twitter_handle.id}-#{latest_note.attachments[0].id}"
          tweet = latest_note.tweet
          assert_equal tweet.tweet_id < 0, true, 'Tweet id should be less than zero'
          assert_equal tweet.tweet_type, params_hash[:tweet_type]
          assert_equal File.exists?(file_name), false
        end
      end
      ticket.destroy
    end

    def test_twitter_reply_to_tweet_ticket_more_than_280_limit
      with_twitter_update_stubbed do

        ticket = create_twitter_ticket

        @account = Account.current

        params_hash = {
            body: Faker::Lorem.paragraphs(5).join[0..500],
            tweet_type: 'mention',
            twitter_handle_id: @twitter_handle.id
        }
        post :tweet, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
        assert_response 400
        ticket.destroy
      end
    end

    def test_twitter_dm_reply_to_tweet_ticket
      ticket = create_twitter_ticket

      dm_text = Faker::Lorem.paragraphs(5).join[0..500]
      @account = Account.current

      reply_id = get_social_id
      dm_reply_params = {
        id: reply_id,
        id_str: reply_id.to_s,
        recipient_id_str: rand.to_s[2..11],
        text: dm_text,
        created_at: Time.zone.now.to_s
      }
      Sidekiq::Testing.inline! do
        with_twitter_dm_stubbed(Twitter::DirectMessage.new(dm_reply_params)) do
          params_hash = {
            body: Faker::Lorem.sentence[0..130],
            tweet_type: 'dm',
            twitter_handle_id: @twitter_handle.id
          }
          post :tweet, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
          assert_response 201
          latest_note = Helpdesk::Note.last
          match_json(private_note_pattern(params_hash, latest_note))
          tweet = latest_note.tweet
          assert_equal tweet.tweet_id < 0, true,"Tweet id should be less than zero"
          assert_equal tweet.tweet_type, params_hash[:tweet_type]
          assert_equal tweet.stream_id, @twitter_handle.dm_stream.id
        end
      end
      ticket.destroy
    end

    def test_twitter_mention_reply_to_dm_ticket_in_tms
      Sidekiq::Testing.inline! do
        with_twitter_update_stubbed do
          ticket = create_twitter_ticket({tweet_type: 'dm'})
          @account = Account.current
          params_hash = {
            body: Faker::Lorem.sentence[0..130],
            tweet_type: 'mention',
            twitter_handle_id: @twitter_handle.id
          }
          post :tweet, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
          assert_response 201
          latest_note = Helpdesk::Note.last
          match_json(private_note_pattern(params_hash, latest_note))
          tweet = latest_note.tweet
          assert_equal tweet.tweet_id < 0, true, 'Tweet id should be less than zero'
          assert_equal tweet.tweet_type, params_hash[:tweet_type]
          ticket.destroy
        end
      end
    end

    def test_ticket_conversations
      Account.stubs(:current).returns(Account.first)
      t = create_ticket
      create_private_note(t)
      create_reply_note(t)
      create_forward_note(t)
      create_feedback_note(t)
      create_fb_note(t)

      with_twitter_update_stubbed do
        create_twitter_note(t)
      end
      # Need to stub Twitter stuff here

      get :ticket_conversations, controller_params(version: 'private', id: t.display_id)
      assert_response 200
      response = parse_response @response.body
      assert_equal 6, response.size
      Account.unstub(:current)
    end

    def test_ticket_conversation_with_ner_data
      dalli_client_unstub
      enable_cache do
        Sidekiq::Testing.inline! do
          customer = add_new_user(@account)
          ticket = create_ticket({:subject => "TEST_TICKET", :description => "FRESH WORKS Test Ticket"})
          note = create_note({:user_id => customer.id, :incoming => 1, :private => false, :ticket_id => ticket.id, :source => 0, :body => "Lets meet at 5pm today", :body_html => "<div>Lets meet at 5pm today</div>"})
          get :ticket_conversations, controller_params(version: 'private', id: ticket.display_id)
          assert_response 200
          response = @response.api_meta[:ner_data]
          assert_not_match response, nil
        end
      end
      ensure
        dalli_client_stub
    end

    def test_ticket_conversation_without_ner_data
      dalli_client_unstub
      enable_cache do
        Sidekiq::Testing.inline! do
          customer = add_new_user(@account)
          ticket = create_ticket({:subject => "TEST_TICKET", :description => "FRESH WORKS Test Ticket"})
          note = create_note({:user_id => customer.id, :incoming => 1, :private => false, :ticket_id => ticket.id, :source => 0, :body => "Test note without ner data", :body_html => "<div>Test note without ner data</div>"})
          get :ticket_conversations, controller_params(version: 'private', id: ticket.display_id)
          assert_response 200
          response = @response.api_meta[:ner_data]
          assert_equal response, nil
        end
      end
      ensure
        dalli_client_stub
    end

    def test_ticket_conversations_with_requester
      t = create_ticket
      create_private_note(t)
      create_reply_note(t)
      create_forward_note(t)
      create_feedback_note(t)
      get :ticket_conversations, controller_params(version: 'private', id: t.display_id, include: 'requester')
      assert_response 200
      match_json(conversations_pattern(ticket, true))
    end

    def test_ticket_conversations_with_pagination
      t = create_ticket
      3.times do
        create_private_note(t)
      end
      get :ticket_conversations, controller_params(version: 'private', id: t.display_id, per_page: 1)
      assert_response 200
      assert JSON.parse(response.body).count == 1
      get :ticket_conversations, controller_params(version: 'private', id: t.display_id, per_page: 1, page: 2)
      assert_response 200
      assert JSON.parse(response.body).count == 1
    end

    def test_ticket_conversations_with_pagination_exceeds_limit
      get :ticket_conversations, controller_params(version: 'private', id: ticket.display_id, per_page: 101)
      assert_response 400
      match_json([bad_request_error_pattern('per_page', :per_page_invalid, max_value: 100)])
    end

    def test_ticket_conversations_with_since_id
      t = create_ticket
      n = create_reply_note(t)
      3.times do
        create_reply_note(t)
      end
      get :ticket_conversations, controller_params(version: 'private', id: t.display_id,
        per_page: 50, page: 1, order_type: "desc", since_id: n.id)
      assert_response 200
      assert JSON.parse(response.body).count == 3
    end

    def test_ticket_conversations_with_since_id_eq_0
      t = create_ticket
      3.times do
        create_reply_note(t)
      end
      get :ticket_conversations, controller_params(version: 'private', id: t.display_id,
        per_page: 50, page: 1, order_type: "desc", since_id: 0)
      assert_response 200
      assert JSON.parse(response.body).count == 3
    end

    def test_ticket_conversations_with_since_id_lt_0
      t = create_ticket
      3.times do
        create_reply_note(t)
      end
      get :ticket_conversations, controller_params(version: 'private', id: t.display_id,
        per_page: 50, page: 1, order_type: "desc", since_id: -1)
      assert_response 200
      assert JSON.parse(response.body).count == 3
    end

    def test_update_without_ticket_access
      User.any_instance.stubs(:has_read_ticket_permission?).returns(false)
      ticket = create_ticket
      note = create_private_note(ticket)
      put :update, construct_params({ version: 'private', id: note.id }, update_note_params_hash)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
      User.any_instance.unstub(:has_read_ticket_permission?)
    end

    def test_update_success
      t = create_ticket
      note = create_private_note(t)
      params_hash = update_note_params_hash
      put :update, construct_params({ version: 'private', id: note.id }, params_hash)
      assert_response 200
      note = Helpdesk::Note.find(note.id)
      match_json(private_update_note_pattern(params_hash, note))
      match_json(private_update_note_pattern({}, note))
    end

    def test_update_with_attachments
      file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      canned_response = create_response(
        title: Faker::Lorem.sentence,
        content_html: Faker::Lorem.paragraph,
        visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
        attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) }
      )
      params_hash = update_note_params_hash.merge('attachments' => [file],
                                                  'attachment_ids' => [attachment_id] | canned_response.shared_attachments.map(&:attachment_id))
      t = create_ticket
      note = create_private_note(t)
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      stub_attachment_to_io do
        put :update, construct_params({ version: 'private', id: note.id }, params_hash)
      end
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 200
      note = Helpdesk::Note.find(note.id)
      match_json(private_update_note_pattern(params_hash, note))
      match_json(private_update_note_pattern({}, note))
      assert_equal 3, note.attachments.count
    end

    def test_update_with_inline_attachment_ids
      t = create_ticket
      note = create_private_note(t)
      inline_attachment_ids = []
      BULK_ATTACHMENT_CREATE_COUNT.times do
        inline_attachment_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
      end
      params_hash = update_note_params_hash.merge(inline_attachment_ids: inline_attachment_ids)
      put :update, construct_params({ version: 'private', id: note.id }, params_hash)
      assert_response 200
      note = Helpdesk::Note.find(note.id)
      match_json(private_update_note_pattern(params_hash, note))
      match_json(private_update_note_pattern({}, note))
      assert_equal inline_attachment_ids.size, note.inline_attachments.size
    end

    def test_update_with_invalid_inline_attachment_ids
      t = create_ticket
      note = create_private_note(t)
      inline_attachment_ids, valid_ids, invalid_ids = [], [], []
      BULK_ATTACHMENT_CREATE_COUNT.times do
        invalid_ids << create_attachment(attachable_type: 'Forums Image Upload').id
      end
      invalid_ids << 0
      BULK_ATTACHMENT_CREATE_COUNT.times do
        valid_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
      end
      inline_attachment_ids = invalid_ids + valid_ids
      params_hash = update_note_params_hash.merge(inline_attachment_ids: inline_attachment_ids)
      put :update, construct_params({ version: 'private', id: note.id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('inline_attachment_ids', :invalid_inline_attachments_list, invalid_ids: invalid_ids.join(', '))])
    end

    def test_update_with_cloud_files
      cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20 }]
      params_hash = update_note_params_hash.merge(cloud_files: cloud_file_params)
      t = create_ticket
      note = create_private_note(t)
      put :update, construct_params({ version: 'private', id: note.id }, params_hash)
      assert_response 200
      note = Helpdesk::Note.find(note.id)
      match_json(private_update_note_pattern(params_hash, note))
      match_json(private_update_note_pattern({}, note))
      assert_equal 1, note.cloud_files.count
    end

    def test_update_on_spammed_ticket
      t = create_ticket(spam: true)
      note = create_private_note(t)
      put :update, construct_params({ version: 'private', id: note.id }, update_note_params_hash)
      assert_response 403
    ensure
      t.update_attributes(spam: false)
    end

    def test_agent_reply_template_with_empty_signature
      remove_wrap_params
      t = create_ticket

      notification_template = '<div>{{ticket.id}}</div>'
      Agent.any_instance.stubs(:signature_value).returns('')
      EmailNotification.any_instance.stubs(:get_reply_template).returns(notification_template)
      bcc_emails = "#{Faker::Internet.email};#{Faker::Internet.email}"
      Account.any_instance.stubs(:bcc_email).returns(bcc_emails)
      get :reply_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200
      match_json(reply_template_pattern(template: "<div>#{t.display_id}</div>",
                                        signature: '',
                                        bcc_emails: bcc_emails.split(';')))

      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_reply_template)
    ensure
      Account.any_instance.unstub(:bcc_email)
    end

    def test_agent_reply_template_with_signature
      remove_wrap_params
      t = create_ticket

      notification_template = '<div>{{ticket.id}}</div>'
      agent_signature = '<div><p>Thanks</p><p>{{ticket.subject}}</p></div>'
      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:get_reply_template).returns(notification_template)
      bcc_emails = "#{Faker::Internet.email},#{Faker::Internet.email}"
      Account.any_instance.stubs(:bcc_email).returns(bcc_emails)
      get :reply_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200

      match_json(reply_template_pattern(template: "<div>#{t.display_id}</div>",
                                        signature: "<div><p>Thanks</p><p>#{t.subject}</p></div>",
                                        bcc_emails: bcc_emails.split(',')))
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_reply_template)
    ensure
      Account.any_instance.unstub(:bcc_email)
    end

    def test_agent_reply_template_with_signature_as_portal_and_helpdesk_name
      remove_wrap_params
      t = create_ticket

      portal = Account.current.portals.find_by_main_portal(true)
      portal_name = portal.name
      portal.name = portal_name+' test'
      portal.save!

      notification_template = '<div>{{helpdesk_name}}<br>{{ticket.portal_name}}</div>'
      agent_signature = '<div>{{helpdesk_name}}<br>{{ticket.portal_name}}</div>'
      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:get_reply_template).returns(notification_template)
      bcc_emails = "#{Faker::Internet.email},#{Faker::Internet.email}"
      Account.any_instance.stubs(:bcc_email).returns(bcc_emails)
      get :reply_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200

      match_json(reply_template_pattern(template: "<div>#{Account.current.helpdesk_name}<br>#{Account.current.portal_name}</div>",
                                        signature: "<div>#{Account.current.helpdesk_name}<br>#{Account.current.portal_name}</div>",
                                        bcc_emails: bcc_emails.split(',')))
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_reply_template)
    ensure
      Account.any_instance.unstub(:bcc_email)
      portal.name = portal_name
      portal.save!
    end

    def test_agent_forward_template_with_signature_as_portal_and_helpdesk_name
      remove_wrap_params
      t = create_ticket

      portal = Account.current.portals.find_by_main_portal(true)
      portal_name = portal.name
      portal.name = portal_name+' test'
      portal.save!

      notification_template = '<div>{{helpdesk_name}}<br>{{ticket.portal_name}}</div>'
      agent_signature = '<div>{{helpdesk_name}}<br>{{ticket.portal_name}}</div>'
      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:get_forward_template).returns(notification_template)
      bcc_emails = "#{Faker::Internet.email},#{Faker::Internet.email}"
      Account.any_instance.stubs(:bcc_email).returns(bcc_emails)
      get :forward_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200
      match_json(forward_template_pattern(template: "<div>#{Account.current.helpdesk_name}<br>#{Account.current.portal_name}</div>",
                                        signature: "<div>#{Account.current.helpdesk_name}<br>#{Account.current.portal_name}</div>",
                                        bcc_emails: bcc_emails.split(',')))
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_forward_template)
    ensure
      Account.any_instance.unstub(:bcc_email)
      portal.name = portal_name
      portal.save!
    end

    def test_agent_reply_template_with_xss_payload
      Account.current.launch(:escape_liquid_for_reply)
      remove_wrap_params
      t = create_ticket(:subject => '<img src=x onerror=prompt("Subject");>')

      notification_template = '<div>{{ticket.subject}}</div>'
      agent_signature = '<div><p>Thanks</p><p>{{ticket.subject}}</p></div>'
      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:get_reply_template).returns(notification_template)
      get :reply_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200

      match_json(reply_template_pattern(
        template: "<div>#{h(t.subject)}</div>",
        signature: "<div><p>Thanks</p><p>#{h(t.subject)}</p></div>"))
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_reply_template)
    end

    def test_agent_signature_in_agent_reply_template_with_xss
      Account.current.launch(:escape_liquid_for_reply)
      remove_wrap_params
      t = create_ticket(:subject => '<svg/onload=alert(document.domain)>;')

      notification_template = '<div>{{ticket.subject}}</div>'
      agent_signature = '<div><p>Thanks</p><p>{{ticket.subject}}</p></div>'
      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:get_reply_template).returns(notification_template)
      get :reply_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200

      match_json(reply_template_pattern(
        template: "<div>#{h(t.subject)}</div>",
        signature: "<div><p>Thanks</p><p>#{h(t.subject)}</p></div>"))
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_reply_template)
    end

    def test_agent_forward_emplate_with_empty_template_and_empty_signature
      t = create_ticket

      Agent.any_instance.stubs(:signature_value).returns('')
      EmailNotification.any_instance.stubs(:present?).returns(false)
      EmailNotification.any_instance.stubs(:get_forward_template).returns('')

      get :forward_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200
      match_json(forward_template_pattern(template: '', signature: ''))

      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:present?)
    end

    def test_agent_forward_emplate_with_empty_template_and_with_signature
      t = create_ticket

      agent_signature = '<div><p>Thanks</p><p>{{ticket.subject}}</p></div>'
      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:present?).returns(false)
      EmailNotification.any_instance.stubs(:get_forward_template).returns('')

      get :forward_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200
      match_json(forward_template_pattern(template: '',
                                        signature: "<div><p>Thanks</p><p>#{t.subject}</p></div>"))

      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:present?)
    end

    def test_agent_forward_template_with_empty_signature
      remove_wrap_params
      t = create_ticket

      notification_template = '<div>{{ticket.id}}</div>'

      Agent.any_instance.stubs(:signature_value).returns('')
      EmailNotification.any_instance.stubs(:get_forward_template).returns(notification_template)

      get :forward_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200
      match_json(forward_template_pattern(template: "<div>#{t.display_id}</div>",
                                        signature: ''))
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_forward_template)
    end

    def test_agent_forward_template_with_signature_and_attachments
      remove_wrap_params
      t = create_ticket(attachments: { resource: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) })
      notification_template = '<div>{{ticket.id}}</div>'
      agent_signature = '<div><p>Thanks</p><p>{{ticket.subject}}</p></div>'

      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:get_forward_template).returns(notification_template)

      get :forward_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200

      match_json(forward_template_pattern(template: "<div>#{t.display_id}</div>",
                                        signature: "<div><p>Thanks</p><p>#{t.subject}</p></div>"))

      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_forward_template)
    end

    def test_agent_forward_template_with_xss_payload
      Account.current.launch(:escape_liquid_for_reply) 
      remove_wrap_params
      t = create_ticket(:subject => '<img src=x onerror=prompt("Subject");>')

      notification_template = '<div>{{ticket.subject}}</div>'

      Agent.any_instance.stubs(:signature_value).returns('')
      EmailNotification.any_instance.stubs(:get_forward_template).returns(notification_template)

      get :forward_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200
      match_json(forward_template_pattern(template: "<div>#{h(t.subject)}</div>",
                                        signature: ''))
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_forward_template)
    end

    def test_agent_signature_in_agent_forward_template_with_xss
      Account.current.launch(:escape_liquid_for_reply) 
      remove_wrap_params
      t = create_ticket(:subject => '<svg/onload=alert(document.domain)>;')

      notification_template = '<div>{{ticket.subject}}</div>'
      agent_signature = '<div><p>Thanks</p><p>{{ticket.subject}}</p></div>'
      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:get_forward_template).returns(notification_template)

      get :forward_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200
      match_json(forward_template_pattern(template: "<div>#{h(t.subject)}</div>",
                                        signature: "<div><p>Thanks</p><p>#{h(t.subject)}</p></div>"))
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_forward_template)
    end

    def test_agent_note_forward_template_with_signature_and_attachments_empty_cc
      note = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2, attachments: { resource: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) })
      notification_template = '<div>{{ticket.id}}</div>'
      agent_signature = '<div><p>Thanks</p><p>{{ticket.subject}}</p></div>'
      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:get_forward_template).returns(notification_template)
      Helpdesk::Ticket.any_instance.stubs(:current_cc_emails).returns([Faker::Internet.email])
      Helpdesk::Ticket.any_instance.stubs(:reply_to_all_emails).returns([Faker::Internet.email])
      get :note_forward_template, controller_params(version: 'private', id: note.id)
      res = parse_response(response.body)
      assert_equal 0, res['cc_emails'].size
      assert_response 200
      match_json(forward_template_pattern(template: "<div>#{ticket.display_id}</div>", signature: "<div><p>Thanks</p><p>#{h(ticket.subject)}</p></div>"))
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_forward_template)
      Helpdesk::Ticket.any_instance.unstub(:current_cc_emails)
      Helpdesk::Ticket.any_instance.unstub(:reply_to_all_emails)
    end

    def test_agent_forward_template_with_signature_and_attachments_empty_cc
      remove_wrap_params
      t = create_ticket(attachments: { resource: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) })
      notification_template = '<div>{{ticket.id}}</div>'
      agent_signature = '<div><p>Thanks</p><p>{{ticket.subject}}</p></div>'

      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:get_forward_template).returns(notification_template)
      Helpdesk::Ticket.any_instance.stubs(:current_cc_emails).returns([Faker::Internet.email])
      Helpdesk::Ticket.any_instance.stubs(:reply_to_all_emails).returns([Faker::Internet.email])
      get :forward_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200
      res = parse_response(response.body)
      assert_equal 0, res['cc_emails'].size
      match_json(forward_template_pattern(template: "<div>#{t.display_id}</div>",
                                          signature: "<div><p>Thanks</p><p>#{t.subject}</p></div>"))
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_forward_template)
      Helpdesk::Ticket.any_instance.unstub(:current_cc_emails)
      Helpdesk::Ticket.any_instance.unstub(:reply_to_all_emails)
    end
    
    def test_note_forward_template_with_empty_signature
      note = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
      notification_template = '<div>{{ticket.id}}</div>'
      Agent.any_instance.stubs(:signature_value).returns('')
      EmailNotification.any_instance.stubs(:get_forward_template).returns(notification_template)
      get :note_forward_template, controller_params(version: 'private', id: note.id)
      assert_response 200
      match_json(forward_template_pattern(template: "<div>#{ticket.display_id}</div>", signature: ''))
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_forward_template)
    end

    def test_note_forward_template_with_signature_and_attachments
      note = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2, attachments: { resource: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) })
      notification_template = '<div>{{ticket.id}}</div>'
      agent_signature = '<div><p>Thanks</p><p>{{ticket.subject}}</p></div>'
      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:get_forward_template).returns(notification_template)
      get :note_forward_template, controller_params(version: 'private', id: note.id)
      assert_response 200
      match_json(forward_template_pattern(template: "<div>#{ticket.display_id}</div>", signature: "<div><p>Thanks</p><p>#{ticket.subject}</p></div>"))
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_forward_template)
    end

    def test_latest_note_forward_template_with_empty_signature
      notification_template = '<div>{{ticket.id}}</div>'
      Agent.any_instance.stubs(:signature_value).returns('')
      EmailNotification.any_instance.stubs(:get_forward_template).returns(notification_template)
      get :latest_note_forward_template, controller_params(version: 'private', id: ticket.display_id)
      assert_response 200
      match_json(forward_template_pattern(template: "<div>#{ticket.display_id}</div>", signature: ''))
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_forward_template)
    end

    def test_latest_note_forward_template_with_signature_and_attachments
      note = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2, attachments: { resource: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) })
      notification_template = '<div>{{ticket.id}}</div>'
      agent_signature = '<div><p>Thanks</p><p>{{ticket.subject}}</p></div>'
      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:get_forward_template).returns(notification_template)
      get :latest_note_forward_template, controller_params(version: 'private', id: ticket.display_id)
      assert_response 200
      match_json(forward_template_pattern(template: "<div>#{ticket.display_id}</div>", signature: "<div><p>Thanks</p><p>#{ticket.subject}</p></div>"))
      res = parse_response(response.body)
      assert_equal 1, res['attachments'].size
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_forward_template)
    end

    def test_latest_note_forward_template_without_conversations
      t = create_ticket(attachments: { resource: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) })
      notification_template = '<div>{{ticket.id}}</div>'
      agent_signature = '<div><p>Thanks</p><p>{{ticket.subject}}</p></div>'
      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:get_forward_template).returns(notification_template)
      get :latest_note_forward_template, controller_params(version: 'private', id: t.display_id)
      assert_response 200
      match_json(forward_template_pattern(template: "<div>#{ticket.display_id}</div>", signature: "<div><p>Thanks</p><p>#{ticket.subject}</p></div>"))
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_forward_template)
    end

    def test_latest_note_forward_template_with_deleted_conversations
      t = create_ticket
      note = create_note(user_id: @agent.id, ticket_id: t.id, source: 2, attachments: { resource: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) })
      note.update_attribute(:deleted, true)
      notification_template = '<div>{{ticket.id}}</div>'
      agent_signature = '<div><p>Thanks</p><p>{{ticket.subject}}</p></div>'
      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:get_forward_template).returns(notification_template)
      get :latest_note_forward_template, controller_params(version: 'private', id: t.display_id)
      assert_response 200
      match_json(forward_template_pattern(template: "<div>#{ticket.display_id}</div>", signature: "<div><p>Thanks</p><p>#{ticket.subject}</p></div>"))
      res = parse_response(response.body)
      assert_equal 0, res['attachments'].size
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_forward_template)
    ensure
      note.update_attribute(:deleted, false)
    end

    def test_note_reply_template_with_signature_and_attachments_and_with_cc
      remove_wrap_params
      t = create_ticket

      notification_template = '<div>{{ticket.id}}</div>'
      agent_signature = '<div><p>Thanks</p><p>{{ticket.subject}}</p></div>'
      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:get_reply_template).returns(notification_template)
      Helpdesk::Ticket.any_instance.stubs(:current_cc_emails).returns([Faker::Internet.email])
      Helpdesk::Ticket.any_instance.stubs(:reply_to_all_emails).returns([Faker::Internet.email])
      bcc_emails = "#{Faker::Internet.email},#{Faker::Internet.email}"
      Account.any_instance.stubs(:bcc_email).returns(bcc_emails)
      get :reply_template, construct_params({ version: 'private', id: t.display_id }, false)
      res = parse_response(response.body)
      assert_equal 1, res['cc_emails'].size
      assert_response 200

      match_json(reply_template_pattern(template: "<div>#{t.display_id}</div>",
                                        signature: "<div><p>Thanks</p><p>#{t.subject}</p></div>",
                                        bcc_emails: bcc_emails.split(',')))
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_reply_template)
      Helpdesk::Ticket.any_instance.unstub(:current_cc_emails)
      Helpdesk::Ticket.any_instance.unstub(:reply_to_all_emails)
    ensure
      Account.any_instance.unstub(:bcc_email)
    end

    def test_latest_note_forward_template_with_signature_and_attachments_and_empty_cc
      note = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2, attachments: { resource: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) })
      notification_template = '<div>{{ticket.id}}</div>'
      agent_signature = '<div><p>Thanks</p><p>{{ticket.subject}}</p></div>'
      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      Helpdesk::Ticket.any_instance.stubs(:current_cc_emails).returns([Faker::Internet.email])
      Helpdesk::Ticket.any_instance.stubs(:reply_to_all_emails).returns([Faker::Internet.email])
      EmailNotification.any_instance.stubs(:get_forward_template).returns(notification_template)
      get :latest_note_forward_template, controller_params(version: 'private', id: ticket.display_id)
      assert_response 200
      match_json(forward_template_pattern(template: "<div>#{ticket.display_id}</div>", signature: "<div><p>Thanks</p><p>#{ticket.subject}</p></div>"))
      res = parse_response(response.body)
      assert_equal 1, res['attachments'].size
      assert_equal 0, res['cc_emails'].size
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_forward_template)
      Helpdesk::Ticket.any_instance.unstub(:current_cc_emails)
      Helpdesk::Ticket.any_instance.unstub(:reply_to_all_emails)
    end

    def test_full_text
      note = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
      note.note_body.full_text_html = note.note_body.body_html + '<div>quoted_text test</div>'
      note.save_note
      note.reload
      get :full_text, construct_params({ version: 'private', id: note.id }, false)
      match_json(full_text_pattern(note))
      assert_response 200
    end

    def test_add_broadcast_note_to_tracker
      enable_adv_ticketing([:link_tickets]) do
        tracker_id = create_tracker_ticket.display_id
        post :broadcast, construct_params({ version: 'private', id: tracker_id }, broadcast_note_params)
        assert_response 201
        match_json(private_note_pattern({}, Helpdesk::Note.last))
      end
    end

    def test_add_broadcast_note_to_tracker_as_read_access_agent
      enable_adv_ticketing([:link_tickets]) do
        begin
          Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
          read_access_agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
          agent_group = create_agent_group_with_read_access(@account, read_access_agent)
          tracker_ticket = create_tracker_ticket
          tracker_id = tracker_ticket.display_id
          tracker_ticket.group_id = agent_group.group_id
          tracker_ticket.save!
          User.stubs(:current).returns(read_access_agent)
          post :broadcast, construct_params({ version: 'private', id: tracker_id }, broadcast_note_params)
          assert_response 201
          match_json(private_note_pattern({}, Helpdesk::Note.last))
        ensure
          read_access_agent.destroy
          Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
        end
      end
    end

    def test_add_broadcast_note_without_feature
      disable_adv_ticketing([:link_tickets]) if Account.current.link_tickets_enabled?
      tracker_id = create_tracker_ticket.display_id
      post :broadcast, construct_params({ version: 'private', id: tracker_id }, broadcast_note_params)
      assert_response 403
      match_json(request_error_pattern(:require_feature, feature: 'Link Tickets'))
    end

    def test_add_broadcast_note_with_inline_attachments
      enable_adv_ticketing([:link_tickets]) do
        tracker_id = create_tracker_ticket.display_id
        inline_attachment_ids = []
        BULK_ATTACHMENT_CREATE_COUNT.times do
          inline_attachment_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
        end
        params_hash = broadcast_note_params.merge(inline_attachment_ids: inline_attachment_ids)
        post :broadcast, construct_params({ version: 'private', id: tracker_id }, params_hash)
        assert_response 201
        note = Helpdesk::Note.last
        match_json(private_note_pattern({}, note))
        assert_equal inline_attachment_ids.size, note.inline_attachments.size 
      end
    end

    def test_add_broadcast_note_with_invalid_inline_attachment_ids
      enable_adv_ticketing([:link_tickets]) do
        tracker_id = create_tracker_ticket.display_id
        inline_attachment_ids, valid_ids, invalid_ids = [], [], []
        BULK_ATTACHMENT_CREATE_COUNT.times do
          invalid_ids << create_attachment(attachable_type: 'Forums Image Upload').id
        end
        invalid_ids << 0
        BULK_ATTACHMENT_CREATE_COUNT.times do
          valid_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
        end
        inline_attachment_ids = invalid_ids + valid_ids
        params_hash = broadcast_note_params.merge(inline_attachment_ids: inline_attachment_ids)
        post :broadcast, construct_params({ version: 'private', id: tracker_id }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('inline_attachment_ids', :invalid_inline_attachments_list, invalid_ids: invalid_ids.join(', '))])
      end
    end

    def test_reply_with_traffic_cop_invalid
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_ticket
      reply = create_reply_note(ticket)
      last_note_id = reply.id
      params_hash = reply_note_params_hash.merge(last_note_id: last_note_id-1 )
      post :reply, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern(:conversation, :traffic_cop_alert)])
      @account.revoke_feature(:traffic_cop)
    end

    def test_agent_private_note_with_traffic_cop_invalid
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_ticket
      reply = create_private_note(ticket)
      last_note_id = reply.id
      params_hash = reply_note_params_hash.merge(last_note_id: last_note_id - 1)
      post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern(:conversation, :traffic_cop_alert)])
      @account.revoke_feature(:traffic_cop)
    end

    def test_public_note_with_traffic_cop_invalid
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_ticket
      note = create_public_note(ticket)
      last_note_id = note.id
      params_hash = create_note_params_hash.merge(last_note_id: last_note_id-1, private: false)
      post :create, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern(:conversation, :traffic_cop_alert)])
      @account.revoke_feature(:traffic_cop)
    end

    def test_public_note_requester
      e_req_notification = @account.email_notifications.find_by_notification_type(EmailNotification::COMMENTED_BY_AGENT)
      e_cc_notification = @account.email_notifications.find_by_notification_type(EmailNotification::PUBLIC_NOTE_CC)
      req_response = e_req_notification.update_attribute(:requester_notification, true) unless e_req_notification.requester_notification?
      cc_response = e_cc_notification.update_attribute(:requester_notification, false) if e_cc_notification.requester_notification?
      ticket = create_ticket
      last_note_id = Helpdesk::Note.last.id
      params_hash = create_note_params_hash.merge(last_note_id: last_note_id, private: false)
      count_of_delayed_jobs_before = Delayed::Job.count
      post :create, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_equal count_of_delayed_jobs_before+3, Delayed::Job.count
      e_req_notification.update_attribute(:requester_notification, false) if req_response
      e_cc_notification.update_attribute(:requester_notification, true) if cc_response
    end

    def test_public_note_cc
      e_req_notification = @account.email_notifications.find_by_notification_type(EmailNotification::COMMENTED_BY_AGENT)
      e_cc_notification = @account.email_notifications.find_by_notification_type(EmailNotification::PUBLIC_NOTE_CC)
      req_response = e_req_notification.update_attribute(:requester_notification, false) if e_req_notification.requester_notification?
      cc_response = e_cc_notification.update_attribute(:requester_notification, true)  unless e_cc_notification.requester_notification?
      ticket = create_ticket
      last_note_id = Helpdesk::Note.last.id
      params_hash = create_note_params_hash.merge(last_note_id: last_note_id, private: false)
      count_of_delayed_jobs_before = Delayed::Job.count
      post :create, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_equal count_of_delayed_jobs_before+3, Delayed::Job.count
      e_req_notification.update_attribute(:requester_notification, true) if req_response
      e_cc_notification.update_attribute(:requester_notification, false) if cc_response
    end

    def test_public_note_both_requester_and_cc
      e_req_notification = @account.email_notifications.find_by_notification_type(EmailNotification::COMMENTED_BY_AGENT)
      e_cc_notification = @account.email_notifications.find_by_notification_type(EmailNotification::PUBLIC_NOTE_CC)
      req_response = e_req_notification.update_attribute(:requester_notification, true) unless e_req_notification.requester_notification?
      cc_response = e_cc_notification.update_attribute(:requester_notification, true)  unless e_cc_notification.requester_notification?
      ticket = create_ticket
      last_note_id = Helpdesk::Note.last.id
      params_hash = create_note_params_hash.merge(last_note_id: last_note_id, private: false)
      count_of_delayed_jobs_before = Delayed::Job.count
      post :create, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_equal count_of_delayed_jobs_before+4, Delayed::Job.count
      e_req_notification.update_attribute(:requester_notification, false) if req_response
      e_cc_notification.update_attribute(:requester_notification, false) if cc_response
    end

    def test_public_note_no_both_requester_and_cc
      e_req_notification = @account.email_notifications.find_by_notification_type(EmailNotification::COMMENTED_BY_AGENT)
      e_cc_notification = @account.email_notifications.find_by_notification_type(EmailNotification::PUBLIC_NOTE_CC)
      req_response = e_req_notification.update_attribute(:requester_notification, false) if e_req_notification.requester_notification?
      cc_response = e_cc_notification.update_attribute(:requester_notification, false)  if e_cc_notification.requester_notification?
      ticket = create_ticket
      last_note_id = Helpdesk::Note.last.id
      params_hash = create_note_params_hash.merge(last_note_id: last_note_id, private: false)
      count_of_delayed_jobs_before = Delayed::Job.count
      post :create, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_equal count_of_delayed_jobs_before+2, Delayed::Job.count
      e_req_notification.update_attribute(:requester_notification, true) if req_response
      e_cc_notification.update_attribute(:requester_notification, true) if cc_response
    end

    def test_reply_with_traffic_cop_valid
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_ticket
      reply = create_reply_note(ticket)
      last_note_id = reply.id
      params_hash = reply_note_params_hash.merge(last_note_id: last_note_id)
      post :reply, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
      @account.revoke_feature(:traffic_cop)
    end

    def test_agent_private_note_with_traffic_cop_valid
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_ticket
      note = create_private_note(ticket)
      last_note_id = note.id
      params_hash = create_note_params_hash.merge(last_note_id: last_note_id, private: false)
      post :create, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
      @account.revoke_feature(:traffic_cop)
    end

    def test_public_note_with_traffic_cop_valid
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_ticket
      note = create_public_note(ticket)
      last_note_id = note.id
      params_hash = create_note_params_hash.merge(last_note_id: last_note_id, private: false)
      post :create, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
      @account.revoke_feature(:traffic_cop)
    end

    def test_reply_with_traffic_cop_without_last_note_id
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_ticket
      reply = create_reply_note(ticket)
      last_note_id = reply.id
      params_hash = reply_note_params_hash
      post :reply, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
      @account.revoke_feature(:traffic_cop)
    end

    def test_private_note_with_traffic_cop_without_last_note_id
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_ticket
      note = create_private_note(ticket)
      last_note_id = note.id
      params_hash = create_note_params_hash.merge(private: false)
      post :create, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
      @account.revoke_feature(:traffic_cop)
    end

    def test_public_note_with_traffic_cop_without_last_note_id
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_ticket
      note = create_public_note(ticket)
      last_note_id = note.id
      params_hash = create_note_params_hash.merge(private: false)
      post :create, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
      @account.revoke_feature(:traffic_cop)
    end

    def test_reply_without_traffic_cop_with_last_note_id
      @account.revoke_feature(:traffic_cop)
      ticket = create_ticket
      reply = create_reply_note(ticket)
      last_note_id = reply.id
      params_hash = reply_note_params_hash.merge(last_note_id: last_note_id-1)
      post :reply, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
    end

    def test_reply_with_existing_attachment
      conversation = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
      attachment = create_attachment(attachable_type: 'Helpdesk::Note', attachable_id: conversation.id)
      params_hash = reply_note_params_hash.merge(attachment_ids: [attachment.id])
      stub_attachment_to_io do
        post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      end
      assert_response 201
      match_json(private_note_pattern(params_hash, Helpdesk::Note.last))
      match_json(private_note_pattern({}, Helpdesk::Note.last))
      note_attachment = Helpdesk::Note.last.attachments.first
      refute note_attachment.id == attachment.id
      assert attachment_content_hash(note_attachment) == attachment_content_hash(attachment)
    end

    def test_public_note_without_traffic_cop_with_last_note_id
      @account.revoke_feature(:traffic_cop)
      ticket = create_ticket
      note = create_public_note(ticket)
      last_note_id = note.id
      params_hash = create_note_params_hash.merge(last_note_id: last_note_id-1, private: false)
      post :create, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
    end

    def test_agent_private_note_without_traffic_cop_with_last_note_id
      @account.revoke_feature(:traffic_cop)
      ticket = create_ticket
      note = create_private_note(ticket)
      last_note_id = note.id
      params_hash = create_note_params_hash.merge(last_note_id: last_note_id - 1, private: false)
      post :create, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
    end

    def test_private_note_with_traffic_cop_with_last_note_id
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_ticket
      note = create_private_note(ticket)
      last_note_id = note.id
      params_hash = create_note_params_hash.merge(private: true, last_note_id: last_note_id - 1)
      post :create, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      @account.revoke_feature(:traffic_cop)
    end

    def test_private_note_with_existing_attachment
      conversation = create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
      attachment = create_attachment(attachable_type: 'Helpdesk::Note', attachable_id: conversation.id)
      params_hash = create_note_params_hash.merge(private: true, attachment_ids: [attachment.id])
      stub_attachment_to_io do
        post :create, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      end
      assert_response 201
      match_json(private_note_pattern(params_hash, Helpdesk::Note.last))
      match_json(private_note_pattern({}, Helpdesk::Note.last))
      note_attachment = Helpdesk::Note.last.attachments.first
      refute note_attachment.id == attachment.id
      assert attachment_content_hash(note_attachment) == attachment_content_hash(attachment)
    end

    def test_public_note_with_traffic_cop_ignoring_private_note
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_ticket
      note = create_private_note(ticket)
      Timecop.travel(1.second)
      BULK_NOTE_CREATE_COUNT.times do
        create_private_note(ticket)
      end
      params_hash = create_note_params_hash.merge(last_note_id: note.id)
      post :create, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      @account.revoke_feature(:traffic_cop)
    end

    def test_tweet_mention_with_traffic_cop_ignoring_public_note
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_twitter_ticket
      note = create_public_note(ticket)
      Timecop.travel(1.seconds)
      BULK_NOTE_CREATE_COUNT.times do
        create_public_note(ticket)
      end
      post :tweet, construct_params({ version: 'private', id: ticket.display_id }, {
        body: Faker::Lorem.sentence[0..130],
        tweet_type: 'mention',
        last_note_id: note.id,
        twitter_handle_id: get_twitter_handle.id
      })
      assert_response 400
      ticket.destroy
      @account.revoke_feature(:traffic_cop)
    end

    def test_tweet_mention_with_traffic_cop_ignoring_private_note
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_twitter_ticket
      note = create_private_note(ticket)
      Timecop.travel(1.second)
      BULK_NOTE_CREATE_COUNT.times do
        create_private_note(ticket)
      end
      post :tweet, construct_params({ version: 'private', id: ticket.display_id }, body: Faker::Lorem.sentence[0..130], tweet_type: 'mention', last_note_id: note.id, twitter_handle_id: get_twitter_handle.id)
      assert_response 400
      ticket.destroy
      @account.revoke_feature(:traffic_cop)
    end

    # def test_tweet_dm_with_traffic_cop_ignoring_public_note
    #   @account.add_feature(:traffic_cop)
    #   Account.current.reload
    #   ticket = create_twitter_ticket
    #   note = create_public_note(ticket)
    #   BULK_NOTE_CREATE_COUNT.times do
    #     create_public_note(ticket)
    #   end
    #   post :tweet, construct_params({ version: 'private', id: ticket.display_id }, {
    #     body: Faker::Lorem.sentence[0..130],
    #     tweet_type: 'dm',
    #     last_note_id: note.id,
    #     twitter_handle_id: get_twitter_handle.id
    #   })
    #   assert_response 400
    #   ticket.destroy
    #   @account.revoke_feature(:traffic_cop)
    # end

    def test_tweet_mention_with_traffic_cop_ignoring_reply
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_twitter_ticket
      note = create_twitter_note(ticket)
      Timecop.travel(1.seconds)
      BULK_NOTE_CREATE_COUNT.times do
        create_public_note(ticket)
      end
      post :tweet, construct_params({ version: 'private', id: ticket.display_id },
      {
        body: Faker::Lorem.sentence[0..130],
        tweet_type: 'mention',
        last_note_id: note.id,
        twitter_handle_id: get_twitter_handle.id
      })
      assert_response 400
      ticket.destroy
      @account.revoke_feature(:traffic_cop)
    end

    def test_facebook_reply_to_fb_post_with_traffic_cop_without_new_conversations
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_ticket_from_fb_post
      note = create_public_note(ticket)
      put_comment_id = "#{(Time.now.ago(2.minutes).utc.to_f * 100_000).to_i}_#{(Time.now.ago(6.minutes).utc.to_f * 100_000).to_i}"
      sample_put_comment = { 'id' => put_comment_id }
      Koala::Facebook::API.any_instance.stubs(:put_comment).returns(sample_put_comment)
      params_hash = { body: Faker::Lorem.paragraph, last_note_id: note.id, msg_type: 'post' }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      Koala::Facebook::API.any_instance.unstub(:put_comment)
      assert_response 201
      @account.revoke_feature(:traffic_cop)
    end

    def test_facebook_reply_to_fb_comment_with_traffic_cop_ignoring_public_note
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_ticket_from_fb_post(true)
      note = create_public_note(ticket)
      sleep 1 # delay introduced so that notes are not created at the same time. Fractional seconds are ignored in tests.
      BULK_NOTE_CREATE_COUNT.times do
        create_public_note(ticket)
      end
      put_comment_id = "#{(Time.now.ago(2.minutes).utc.to_f * 100_000).to_i}_#{(Time.now.ago(6.minutes).utc.to_f * 100_000).to_i}"
      sample_put_comment = { 'id' => put_comment_id }
      fb_comment_note = ticket.notes.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['facebook']).first
      Koala::Facebook::API.any_instance.stubs(:put_comment).returns(sample_put_comment)
      params_hash = { body: Faker::Lorem.paragraph, note_id: fb_comment_note.id, last_note_id: note.id }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      Koala::Facebook::API.any_instance.unstub(:put_comment)
      assert_response 400
      @account.revoke_feature(:traffic_cop)
    end

    def test_facebook_reply_to_fb_direct_message_with_traffic_cop_ignoring_public_note
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_ticket_from_fb_direct_message
      note = create_public_note(ticket)
      sleep 1 # delay introduced so that notes are not created at the same time. Fractional seconds are ignored in tests.
      sample_reply_dm = { 'id' => Time.now.utc.to_i + 5 }
      BULK_NOTE_CREATE_COUNT.times do
        create_public_note(ticket)
      end
      Koala::Facebook::API.any_instance.stubs(:put_object).returns(sample_reply_dm)
      params_hash = { body: Faker::Lorem.paragraph, last_note_id: note.id }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      Koala::Facebook::API.any_instance.unstub(:put_object)
      assert_response 400
      @account.revoke_feature(:traffic_cop)
    end

    def test_facebook_reply_to_fb_comment_with_traffic_cop_ignoring_private_note
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_ticket_from_fb_post(true)
      note = create_private_note(ticket)
      sleep 1 # delay introduced so that notes are not created at the same time. Fractional seconds are ignored in tests.
      BULK_NOTE_CREATE_COUNT.times do
        create_private_note(ticket)
      end
      put_comment_id = "#{(Time.now.ago(2.minutes).utc.to_f * 100_000).to_i}_#{(Time.now.ago(6.minutes).utc.to_f * 100_000).to_i}"
      sample_put_comment = { 'id' => put_comment_id }
      fb_comment_note = ticket.notes.where(source: Account.current.helpdesk_sources.note_source_keys_by_token['facebook']).first
      Koala::Facebook::API.any_instance.stubs(:put_comment).returns(sample_put_comment)
      params_hash = { body: Faker::Lorem.paragraph, note_id: fb_comment_note.id, last_note_id: note.id }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      Koala::Facebook::API.any_instance.unstub(:put_comment)
      assert_response 400
      @account.revoke_feature(:traffic_cop)
    end

    def test_facebook_reply_to_fb_direct_message_with_traffic_cop_ignoring_private_note
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_ticket_from_fb_direct_message
      note = create_private_note(ticket)
      sleep 1 # delay introduced so that notes are not created at the same time. Fractional seconds are ignored in tests.
      sample_reply_dm = { 'id' => Time.now.utc.to_i + 5 }
      BULK_NOTE_CREATE_COUNT.times do
        create_private_note(ticket)
      end
      Koala::Facebook::API.any_instance.stubs(:put_object).returns(sample_reply_dm)
      params_hash = { body: Faker::Lorem.paragraph, last_note_id: note.id }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      Koala::Facebook::API.any_instance.unstub(:put_object)
      assert_response 400
      @account.revoke_feature(:traffic_cop)
    end

    def test_facebook_reply_to_fb_post_with_traffic_cop_ignoring_reply
      @account.add_feature(:traffic_cop)
      Account.current.reload
      ticket = create_ticket_from_fb_post
      note = create_fb_note(ticket)
      sleep 1 # delay introduced so that notes are not created at the same time. Fractional seconds are ignored in tests.
      put_comment_id = "#{(Time.now.ago(2.minutes).utc.to_f * 100_000).to_i}_#{(Time.now.ago(6.minutes).utc.to_f * 100_000).to_i}"
      sample_put_comment = { 'id' => put_comment_id }
      BULK_NOTE_CREATE_COUNT.times do
        create_public_note(ticket)
      end
      Koala::Facebook::API.any_instance.stubs(:put_comment).returns(sample_put_comment)
      params_hash = { body: Faker::Lorem.paragraph, last_note_id: note.id }
      post :facebook_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      Koala::Facebook::API.any_instance.unstub(:put_comment)
      assert_response 400
      @account.revoke_feature(:traffic_cop)
    end

    def test_archive_note_with_redirection
      @account.make_current
      @account.enable_ticket_archiving(ARCHIVE_DAYS)
      @account.features.send(:archive_tickets).create
      create_archive_ticket_with_assoc(
        created_at: TICKET_UPDATED_DATE,
        updated_at: TICKET_UPDATED_DATE,
        create_conversations: true
      )
      archive_ticket = @account.archive_tickets.find_by_ticket_id( @archive_ticket.id)
      note_json = archive_ticket.notes.conversations.map do |note|
        payload = note_pattern({}, note)
        archive_note_payload(note, payload)
      end

      get :ticket_conversations, controller_params(version: 'private',id: archive_ticket.display_id)
      assert_response 301
    ensure
      cleanup_archive_ticket(@archive_ticket)
    end

    def test_reply_template_cc
      cc_emails = [Faker::Internet.email, Faker::Internet.email]
      t = create_ticket(cc_emails: cc_emails)
      get :reply_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200
      assert(JSON.parse(response.body)['cc_emails'] == cc_emails)
      assert(JSON.parse(response.body)['cc_emails'] == t.cc_email[:cc_emails])
      cc_emails.pop
      @note = t.notes.build(private: false, user_id: @agent.id, account_id: @account.id, source: Account.current.helpdesk_sources.note_source_keys_by_token['email'], cc_emails: cc_emails)
      @note.save
      get :reply_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200
      assert(JSON.parse(response.body)['cc_emails'] == cc_emails)
    end

    def test_reply_with_post_to_forum_topic
      t = new_ticket_from_forum_topic
      create_normal_reply_for(t)
      old_posts_count = t.ticket_topic.topic.posts.count
      params_hash = reply_note_params_hash.merge(full_text: Faker::Lorem.paragraph(10), post_to_forum_topic: true)
      post :reply, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
      assert_equal old_posts_count + 1, t.reload.ticket_topic.topic.posts.count
    end

    def test_reply_without_post_to_forum_topic
      t = new_ticket_from_forum_topic
      create_normal_reply_for(t)
      old_posts_count = t.ticket_topic.topic.posts.count
      params_hash = reply_note_params_hash.merge(full_text: Faker::Lorem.paragraph(10), post_to_forum_topic: false)
      post :reply, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
      assert_equal old_posts_count, t.reload.ticket_topic.topic.posts.count
    end

    def test_reply_with_post_to_forum_topic_with_exception
      t = new_ticket_from_forum_topic
      create_normal_reply_for(t)
      old_posts_count = t.ticket_topic.topic.posts.count
      Topic.any_instance.stubs(:clone_cloud_files_attachments).raises(Exception)
      params_hash = reply_note_params_hash.merge(full_text: Faker::Lorem.paragraph(10), post_to_forum_topic: true)
      post :reply, construct_params({ version: 'private', id: t.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
      assert_equal old_posts_count, t.reload.ticket_topic.topic.posts.count
    end

    def test_reply_with_post_to_forum_topic_with_attachments
      t = new_ticket_from_forum_topic
      note = create_normal_reply_for(t)
      create_shared_attachment(note)
      attachment_ids = []
      inline_attachment_ids = []
      BULK_ATTACHMENT_CREATE_COUNT.times do
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
        inline_attachment_ids << create_attachment(attachable_type: 'Tickets Image Upload').id
      end
      old_posts_count = t.ticket_topic.topic.posts.count
      params_hash = reply_note_params_hash.merge(attachment_ids: attachment_ids, inline_attachment_ids: inline_attachment_ids, user_id: @agent.id, post_to_forum_topic: true, cloud_files: [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20 }])
      stub_attachment_to_io do
        post :reply, construct_params({ version: 'private', id: t.display_id }, params_hash)
      end
      assert_response 201
      note = Helpdesk::Note.last
      post = t.reload.ticket_topic.topic.posts.last
      match_json(private_note_pattern(params_hash, Helpdesk::Note.last))
      match_json(private_note_pattern({}, Helpdesk::Note.last))
      assert note.attachments.size == attachment_ids.size
      assert_equal post.attachments.count, note.attachments.count
      assert_equal post.inline_attachments.count, note.inline_attachments.count
      assert_equal post.cloud_files.count, note.cloud_files.count
    end

    def test_ecommerce_reply_without_params
      ticket = create_ebay_ticket
      post :ecommerce_reply, construct_params({ version: 'private', id: ticket.display_id }, {})
      assert_response 400
      match_json([bad_request_error_pattern('body', :datatype_mismatch, code: :missing_field, expected_data_type: String)])
    end

    def test_ecommerce_reply_with_invalid_ticket
      ticket = create_ticket
      body_hash = { body: Faker::Lorem.characters(10) }
      post :ecommerce_reply, construct_params({ version: 'private', id: ticket.display_id }, body_hash)
      assert_response 400
      match_json([bad_request_error_pattern('ticket_id', :not_an_ebay_ticket)])
    end

    def test_ecommerce_reply_with_invalid_privilege
      ticket = create_ebay_ticket
      User.any_instance.stubs(:privilege?).with(:reply_ticket).returns(false)
      body_hash = { body: Faker::Lorem.paragraph }
      Ecommerce::Ebay::Api.any_instance.stubs(:make_ebay_api_call).returns(timestamp: Time.current)
      post :ecommerce_reply, construct_params({ version: 'private', id: ticket.display_id }, body_hash)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    ensure
      User.any_instance.unstub(:privilege?)
      Ecommerce::Ebay::Api.any_instance.unstub(:make_ebay_api_call)
    end

    def test_ecommerce_reply_with_invalid_agent_id
      ticket = create_ebay_ticket
      body_hash = { body: Faker::Lorem.paragraph, agent_id: User.last.try(:id) + 10 }
      post :ecommerce_reply, construct_params({ version: 'private', id: ticket.display_id }, body_hash)
      assert_response 400
      match_json([bad_request_error_pattern('agent_id', :absent_in_db, resource: :agent, attribute: :agent_id)])
    end

    def test_ecommerce_reply
      ticket = create_ebay_ticket
      body_hash = { body: Faker::Lorem.paragraph }
      Ecommerce::Ebay::Api.any_instance.stubs(:make_ebay_api_call).returns(timestamp: Time.current)
      post :ecommerce_reply, construct_params({ version: 'private', id: ticket.display_id }, body_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(body_hash, latest_note))
    ensure
      Ecommerce::Ebay::Api.any_instance.unstub(:make_ebay_api_call)
    end

    def test_ecommerce_reply_with_ebay_api_failure
      ticket = create_ebay_ticket
      body_hash = { body: Faker::Lorem.paragraph }
      post :ecommerce_reply, construct_params({ version: 'private', id: ticket.display_id }, body_hash)
      assert_response 400
    end

    def test_ecommerce_reply_with_note_save_failure
      ticket = create_ebay_ticket
      Helpdesk::Note.any_instance.stubs(:save_note).returns(false)
      body_hash = { body: Faker::Lorem.paragraph }
      post :ecommerce_reply, construct_params({ version: 'private', id: ticket.display_id }, body_hash)
      assert_response 400
    end

    def test_ecommerce_reply_with_invalid_body
      ticket = create_ticket
      body_hash = { body: Faker::Lorem.characters(2010) }
      post :ecommerce_reply, construct_params({ version: 'private', id: ticket.display_id }, body_hash)
      assert_response 400
    end

    def test_ecommerce_reply_with_attachments
      attachment_ids = []
      file = fixture_file_upload('files/image4kb.png', 'image/png')
      attachment_ids << create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
      ticket = create_ebay_ticket
      params_hash = {
        body: Faker::Lorem.sentence[0..130],
        attachment_ids: attachment_ids
      }
      Ecommerce::Ebay::Api.any_instance.stubs(:make_ebay_api_call).returns(timestamp: Time.current)
      post :ecommerce_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      match_json(private_note_pattern(params_hash, Helpdesk::Note.last))
      assert Helpdesk::Note.last.attachments.size == attachment_ids.size
    ensure
      @account.ebay_accounts.last.delete
      Ecommerce::Ebay::Api.any_instance.unstub(:make_ebay_api_call)
    end

    def test_ecommerce_reply_with_invalid_attachment_size
      attachment_ids = []
      file = fixture_file_upload('files/image4kb.png', 'image/png')
      attachment_ids << create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: @agent.id).id
      ticket = create_ebay_ticket
      params_hash = {
        body: Faker::Lorem.sentence[0..130],
        attachment_ids: attachment_ids
      }
      invalid_attachment_limit = @account.attachment_limit + 1
      Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(invalid_attachment_limit.megabytes)
      Ecommerce::Ebay::Api.any_instance.stubs(:make_ebay_api_call).returns(timestamp: Time.current)
      post :ecommerce_reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      match_json([bad_request_error_pattern(:attachment_ids, :invalid_size, max_size: "#{@account.attachment_limit} MB", current_size: "#{invalid_attachment_limit} MB")])
      assert_response 400
    ensure
      @account.ebay_accounts.last.delete
      Ecommerce::Ebay::Api.any_instance.unstub(:make_ebay_api_call)
      Helpdesk::Attachment.any_instance.unstub(:content_file_size)
    end

    def test_email_notification_without_notifying_emails
      current_account = Account.current
      assigned_agent = add_test_agent(@account)
      ticket = create_ticket(requester_id: assigned_agent.id)
      params_hash = create_note_params_hash.merge(private: true, notify_emails: [])
      count_of_delayed_jobs_before = Delayed::Job.count
      post :create, construct_params({ version: 'private', id: ticket.display_id, user_id: assigned_agent.id }, params_hash)
      assert_equal count_of_delayed_jobs_before + 1, Delayed::Job.count
    end

    def test_email_notification_with_invalid_notifying_emails
      current_account = Account.current
      Account.any_instance.stubs(:new_email_regex_enabled?).returns(true)
      assigned_agent = add_test_agent(@account)
      ticket = create_ticket(requester_id: assigned_agent.id)
      params_hash = create_note_params_hash.merge(private: true, notify_emails: ['test.@test.com'])
      post :create, construct_params({ version: 'private', id: ticket.display_id, user_id: assigned_agent.id }, params_hash)
      match_json([bad_request_error_pattern('notify_emails', :array_invalid_format, accepted: 'valid email address')])
      assert_response 400
    ensure
      Account.any_instance.unstub(:new_email_regex_enabled?)
    end

    def test_html_to_text_conversion_in_conversations
      ticket = create_ticket
      body_html = "<table border='1'><tbody><tr><td>A</td><td>B</td></tr><tr><td>C</td><td>D</td></tr></tbody></table><div>"
      post :create, construct_params(version: 'private', id: ticket.display_id, body: body_html)
      response_text = JSON.parse(response.body)['body_text']
      required_text = 'A  B  C  D'
      assert_equal response_text, required_text
    end

    def test_reply_with_secure_field_and_ticket_params
      Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
      ::Tickets::SendAndSetWorker.clear
      add_privilege(User.current, :view_secure_field)
      add_privilege(User.current, :edit_secure_field)
      create_custom_field_dn('custom_card_no_test', 'secure_text')
      ticket = create_ticket(requester_id: User.current.id)
      uuid = SecureRandom.hex
      request.stubs(:uuid).returns(uuid)
      ticket_params = { ticket: { priority: 3, status: 3, source: 5, type: 'Problem', custom_fields: { '_custom_card_no_test' => 'c0376b8ce26458010ceceb9de2fde759' } } }
      params_hash = reply_note_params_hash.merge!(ticket_params)
      CustomRequestStore.store[:private_api_request] = true
      post :reply, construct_params({ id: ticket.display_id }, params_hash)
      assert_response 201
      token = @response.api_meta[:vault_token]
      key = ApiTicketsTestHelper::PRIVATE_KEY_STRING
      assert_equal ::Tickets::SendAndSetWorker.jobs.size, 1
      payload = JSON.parse(JWE.decrypt(token, key))
      assert_equal payload['action'], 2
      assert_equal payload['otype'], 'ticket'
      assert_equal payload['oid'], ticket.id
      assert_equal payload['user_id'], User.current.id
      assert_equal payload['uuid'].to_s, uuid
      assert_equal payload['iss'], 'fd/poduseast'
      assert_equal payload['scope'], ['custom_card_no_test']
      assert_equal payload['exp'], payload['iat'] + PciConstants::EXPIRY_DURATION.to_i
      assert_equal payload['accid'], Account.current.id
      assert_equal payload['portal'], 1
    ensure
      CustomRequestStore.store[:private_api_request] = false
      ticket.destroy
      request.unstub(:uuid)
      Account.current.ticket_fields.find_by_name('custom_card_no_test_1').destroy
      remove_privilege(User.current, :view_secure_field)
      remove_privilege(User.current, :edit_secure_field)
      Account.any_instance.unstub(:pci_compliance_field_enabled?)
    end

    def test_reply_with_ticket_params_and_secure_field_without_prefix
      Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
      ::Tickets::SendAndSetWorker.clear
      add_privilege(User.current, :view_secure_field)
      add_privilege(User.current, :edit_secure_field)
      create_custom_field_dn('custom_card_no_test', 'secure_text')
      ticket = create_ticket(requester_id: User.current.id)
      uuid = SecureRandom.hex
      request.stubs(:uuid).returns(uuid)
      ticket_params = { ticket: { priority: 3, status: 3, source: 5, type: 'Problem', custom_fields: { 'custom_card_no_test' => 'c0376b8ce26458010ceceb9de2fde759' } } }
      params_hash = reply_note_params_hash.merge!(ticket_params)
      CustomRequestStore.store[:private_api_request] = true
      post :reply, construct_params({ id: ticket.display_id }, params_hash)
      assert_response 400
    ensure
      CustomRequestStore.store[:private_api_request] = false
      ticket.destroy
      request.unstub(:uuid)
      Account.current.ticket_fields.find_by_name('custom_card_no_test_1').destroy
      remove_privilege(User.current, :view_secure_field)
      remove_privilege(User.current, :edit_secure_field)
      Account.any_instance.unstub(:pci_compliance_field_enabled?)
    end

    def test_reply_with_ticket_params_and_secure_field_without_privilege
      ::Tickets::SendAndSetWorker.clear
      Account.any_instance.stubs(:pci_compliance_field_enabled?).returns(true)
      create_custom_field_dn('custom_card_no_test', 'secure_text')
      ticket = create_ticket(requester_id: User.current.id)
      uuid = SecureRandom.hex
      request.stubs(:uuid).returns(uuid)
      ticket_params = { ticket: { priority: 3, status: 3, source: 5, type: 'Problem', custom_fields: { '_custom_card_no_test' => 'c0376b8ce26458010ceceb9de2fde759' } } }
      params_hash = reply_note_params_hash.merge!(ticket_params)
      CustomRequestStore.store[:private_api_request] = true
      post :reply, construct_params({ id: ticket.display_id }, params_hash)
      assert_response 400
    ensure
      CustomRequestStore.store[:private_api_request] = false
      ticket.destroy
      request.unstub(:uuid)
      Account.current.ticket_fields.find_by_name('custom_card_no_test_1').destroy
      Account.any_instance.unstub(:pci_compliance_field_enabled?)
    end

    def test_update_with_public_note_with_read_scope
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group.id).first
      agent_group.write_access = false
      agent_group.save!
      agent.make_current
      note = create_public_note(ticket)
      ticket = create_ticket({}, group)
      login_as(agent)
      put :update, construct_params({ version: 'private', id: note.id }, update_note_params_hash)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    ensure
      group.destroy if group.present?
    end

    def test_create_public_note_with_read_scope
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group.id).first
      agent_group.write_access = false
      agent_group.save!
      agent.make_current
      ticket = create_ticket({}, group)
      params_hash = create_note_params_hash
      params_hash[:private] = false
      login_as(agent)
      post :create, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 403
    ensure
      group.destroy if group.present?
    end

    def test_reply_with_full_text_with_read_scope
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group.id).first
      agent_group.write_access = false
      agent_group.save!
      agent.make_current
      ticket = create_ticket({}, group)
      login_as(agent)
      params_hash = reply_note_params_hash.merge(full_text: Faker::Lorem.paragraph(10))
      post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 403
    ensure
      group.destroy if group.present?
    end

    def test_destroy_with_public_note_with_read_scope
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group.id).first
      agent_group.write_access = false
      agent_group.save!
      agent.make_current
      note = create_public_note(ticket)
      ticket = create_ticket({}, group)
      login_as(agent)
      delete :destroy, construct_params(id: note.id)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    ensure
      group.destroy if group.present?
    end

    def test_create_forward_note_with_read_scope
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group.id).first
      agent_group.write_access = false
      agent_group.save!
      agent.make_current
      ticket = create_ticket({}, group)
      login_as(agent)
      params_hash = forward_note_params_hash.merge(full_text: Faker::Lorem.paragraph(10))
      post :forward, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 403
    ensure
      group.destroy if group.present?
    end

    def test_destroy_with_forward_note_with_read_scope
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group.id).first
      agent_group.write_access = false
      agent_group.save!
      agent.make_current
      ticket = create_ticket({}, group)
      note = create_forward_note(ticket)
      login_as(agent)
      delete :destroy, construct_params(id: note.id)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    ensure
      group.destroy if group.present?
    end

    def test_destroy_with_reply_note_with_read_scope
      agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
      group = create_group_with_agents(@account, agent_list: [agent.id])
      agent_group = agent.agent_groups.where(group_id: group.id).first
      agent_group.write_access = false
      agent_group.save!
      agent.make_current
      ticket = create_ticket({}, group)
      note = create_reply_note(ticket)
      login_as(agent)
      delete :destroy, construct_params(id: note.id)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    ensure
      group.destroy if group.present?
    end

    def test_reply_with_valid_reply_ticket_id_param
      params_hash = reply_note_params_hash.merge(full_text: Faker::Lorem.paragraph(10), reply_ticket_id: ticket.display_id)
      post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(private_note_pattern(params_hash, latest_note))
      match_json(private_note_pattern({}, latest_note))
    end

    def test_reply_with_invalid_reply_ticket_id_param
      params_hash = reply_note_params_hash.merge(full_text: Faker::Lorem.paragraph(10), reply_ticket_id: rand(10_000))
      post :reply, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('reply_ticket_id', :invalid_ticket_reply)])
    end

    private

      def archive_note_payload(note, payload)
        payload.merge!({
          source: note.source,
          from_email: note.from_email,
          cc_emails: note.cc_emails,
          bcc_emails: note.bcc_emails,
          cloud_files: []
        })
        payload
      end
  end
end
