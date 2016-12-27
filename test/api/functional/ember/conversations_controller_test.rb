require_relative '../../test_helper'
['canned_responses_helper.rb', 'group_helper.rb', 'social_tickets_creation_helper.rb', 'twitter_helper.rb', 'dynamo_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module Ember
  class ConversationsControllerTest < ActionController::TestCase
    include ConversationsTestHelper
    include AttachmentsTestHelper
    include GroupHelper
    include CannedResponsesHelper
    include TicketsTestHelper
    include SocialTestHelper
    include SocialTicketsCreationHelper
    include TwitterHelper
    include DynamoHelper
    include SurveysTestHelper

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
      Helpdesk::Note.where(source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'], deleted: false).first || create_note(user_id: @agent.id, ticket_id: ticket.id, source: 2)
    end

    def create_note_params_hash
      body = Faker::Lorem.paragraph
      agent_email1 = Agent.last.user.email
      agent_email2 = Agent.find { |x| x.user.email != agent_email1 }.try(:user).try(:email) || add_test_agent(@account, role: Role.find_by_name('Agent').id).email
      email = [agent_email1, agent_email2]
      params_hash = { body: body, notify_emails: email, private: true }
      params_hash
    end

    def reply_note_params_hash
      body = Faker::Lorem.paragraph
      email = [Faker::Internet.email, Faker::Internet.email]
      bcc_emails = [Faker::Internet.email, Faker::Internet.email]
      email_config = @account.email_configs.where(active: true).first || create_email_config
      params_hash = { body: body, cc_emails: email, bcc_emails: bcc_emails, from_email: email_config.reply_email }
      params_hash
    end

    def forward_note_params_hash
      body = Faker::Lorem.paragraph
      to_emails = [Faker::Internet.email]
      cc_emails = [Faker::Internet.email, Faker::Internet.email]
      bcc_emails = [Faker::Internet.email, Faker::Internet.email]
      email_config = @account.email_configs.where(active: true).first || create_email_config
      params_hash = { body: body, to_emails: to_emails, cc_emails: cc_emails, bcc_emails: bcc_emails, from_email: email_config.reply_email }
      params_hash
    end

    def update_note_params_hash
      body = Faker::Lorem.paragraph
      params_hash = { body: body }
      params_hash
    end

    def test_create_with_incorrect_attachment_type
      attachment_ids = ['A', 'B', 'C']
      params_hash = create_note_params_hash.merge({attachment_ids: attachment_ids})
      post :create, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      match_json([bad_request_error_pattern(:attachment_ids, :array_datatype_mismatch, expected_data_type: 'Positive Integer')])
      assert_response 400
    end

    def test_create_with_invalid_attachment_ids
      attachment_ids = []
      attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      invalid_ids = [attachment_ids.last + 10, attachment_ids.last + 20]
      params_hash = create_note_params_hash.merge({attachment_ids: (attachment_ids | invalid_ids)})
      post :create, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      match_json([bad_request_error_pattern(:attachment_ids, :invalid_list, list: invalid_ids.join(', '))])
      assert_response 400
    end

    def test_create_with_invalid_attachment_size
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params_hash = create_note_params_hash.merge({attachment_ids: [attachment_id]})
      Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(20_000_000)
      post :create, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      Helpdesk::Attachment.any_instance.unstub(:content_file_size)
      match_json([bad_request_error_pattern(:attachment_ids, :invalid_size, max_size: '15 MB', current_size: '19.1 MB')])
      assert_response 400
    end

    def test_create_with_attachment_ids
      attachment_ids = []
      rand(2..10).times do
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      end
      params_hash = create_note_params_hash.merge({attachment_ids: attachment_ids})
      post :create, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      match_json(note_pattern(params_hash, Helpdesk::Note.last))
      match_json(note_pattern({}, Helpdesk::Note.last))
      assert Helpdesk::Note.last.attachments.size == attachment_ids.size
    end

    def test_create_with_attachment_and_attachment_ids
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      file1 = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
      file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
      attachments = [file1, file2]
      params_hash = create_note_params_hash.merge({attachment_ids: [attachment_id], attachments: attachments})
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data' 
      post :create, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 201
      match_json(note_pattern(params_hash, Helpdesk::Note.last))
      match_json(note_pattern({}, Helpdesk::Note.last))
      assert Helpdesk::Note.last.attachments.size == (attachments.size + 1)
    end

    def test_create_with_cloud_files_upload
      cloud_file_params = [{ filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 },
                           { filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 }]
      params = create_note_params_hash.merge(cloud_files: cloud_file_params)
      post :create, construct_params({version: 'private', id: ticket.display_id }, params)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params, latest_note))
      match_json(note_pattern({}, latest_note))
      assert latest_note.cloud_files.count == 2
    end

    def test_create_with_shared_attachments
      canned_response = create_response(
          title: Faker::Lorem.sentence,
          content_html: Faker::Lorem.paragraph,
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) })
      params = create_note_params_hash.merge(attachment_ids: canned_response.shared_attachments.map(&:attachment_id))
      post :create, construct_params({version: 'private', id: create_ticket.display_id }, params)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params, latest_note))
      match_json(note_pattern({}, latest_note))
      assert latest_note.attachments.count == 1
    end

    def test_reply_with_invalid_attachment_ids
      attachment_ids = []
      attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      invalid_ids = [attachment_ids.last + 10, attachment_ids.last + 20]
      params_hash = reply_note_params_hash.merge({attachment_ids: (attachment_ids | invalid_ids)})
      post :reply, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      match_json([bad_request_error_pattern(:attachment_ids, :invalid_list, list: invalid_ids.join(', '))])
      assert_response 400
    end

    def test_reply_with_invalid_attachment_size
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params_hash = reply_note_params_hash.merge({attachment_ids: [attachment_id]})
      Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(20_000_000)
      post :reply, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      Helpdesk::Attachment.any_instance.unstub(:content_file_size)
      match_json([bad_request_error_pattern(:attachment_ids, :invalid_size, max_size: '15 MB', current_size: '19.1 MB')])
      assert_response 400
    end

    def test_reply_with_attachment_ids
      attachment_ids = []
      rand(2..10).times do
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      end
      params_hash = reply_note_params_hash.merge({attachment_ids: attachment_ids, user_id: @agent.id})
      post :reply, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      match_json(note_pattern(params_hash, Helpdesk::Note.last))
      match_json(note_pattern({}, Helpdesk::Note.last))
      assert Helpdesk::Note.last.attachments.size == attachment_ids.size
    end

    def test_reply_with_attachment_and_attachment_ids
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      file1 = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
      file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
      attachments = [file1, file2]
      params_hash = reply_note_params_hash.merge({attachment_ids: [attachment_id], attachments: attachments})
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data' 
      post :reply, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 201
      match_json(note_pattern(params_hash, Helpdesk::Note.last))
      match_json(note_pattern({}, Helpdesk::Note.last))
      assert Helpdesk::Note.last.attachments.size == (attachments.size + 1)
    end

    def test_reply_with_cloud_files_upload
      cloud_file_params = [{ filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 },
                           { filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 }]
      params = reply_note_params_hash.merge(cloud_files: cloud_file_params)
      post :reply, construct_params({version: 'private', id: ticket.display_id }, params)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params, latest_note))
      match_json(note_pattern({}, latest_note))
      assert latest_note.cloud_files.count == 2
    end

    def test_reply_with_shared_attachments
      canned_response = create_response(
          title: Faker::Lorem.sentence,
          content_html: Faker::Lorem.paragraph,
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) })
      params = reply_note_params_hash.merge(attachment_ids: canned_response.shared_attachments.map(&:attachment_id))
      post :reply, construct_params({version: 'private', id: create_ticket.display_id }, params)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params, latest_note))
      match_json(note_pattern({}, latest_note))
      assert latest_note.attachments.count == 1
    end
    
    def test_reply_with_inapplicable_survey_option
      survey = Account.current.survey
      survey.send_while = rand(1..3)
      survey.save
      t = create_ticket
      params_hash = reply_note_params_hash.merge(send_survey: true)
      post :reply, construct_params({version: 'private', id: t.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern(:send_survey, :should_be_blank)])
    end

    def test_reply_without_survey_link
      survey = Account.current.survey
      survey.send_while = 4
      survey.save
      t = create_ticket
      params_hash = reply_note_params_hash.merge(send_survey: false)
      post :reply, construct_params({version: 'private', id: t.display_id }, params_hash)
      assert_response 201
      match_json(note_pattern(params_hash, Helpdesk::Note.last))
      match_json(note_pattern({}, Helpdesk::Note.last))
    end

    def test_reply_with_survey_link
      survey = Account.current.survey
      survey.send_while = 4
      survey.save
      t = create_ticket
      params_hash = reply_note_params_hash.merge(send_survey: true)
      post :reply, construct_params({version: 'private', id: t.display_id }, params_hash)
      assert_response 201
      match_json(note_pattern(params_hash, Helpdesk::Note.last))
      match_json(note_pattern({}, Helpdesk::Note.last))
    end

    def test_forward_with_invalid_cc_emails_count
      cc_emails = []
      50.times do
        cc_emails << Faker::Internet.email
      end
      params = forward_note_params_hash.merge(cc_emails: cc_emails, bcc_emails: cc_emails)
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params)
      assert_response 400
      match_json([bad_request_error_pattern('cc_emails', :too_long, element_type: :values, max_count: "#{ApiTicketConstants::MAX_EMAIL_COUNT}", current_count: 50),
                  bad_request_error_pattern('bcc_emails', :too_long, element_type: :values, max_count: "#{ApiTicketConstants::MAX_EMAIL_COUNT}", current_count: 50)])
    end

    def test_forward_with_ticket_trashed
      Helpdesk::SchemaLessTicket.any_instance.stubs(:trashed).returns(true)
      params_hash = forward_note_params_hash
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      Helpdesk::SchemaLessTicket.any_instance.unstub(:trashed)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end

    def test_forward_without_ticket_privilege
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      params_hash = forward_note_params_hash
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      User.any_instance.unstub(:has_ticket_permission?)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end

    def test_forward
      params_hash = forward_note_params_hash
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      match_json(note_pattern(params_hash, Helpdesk::Note.last))
      match_json(note_pattern({}, Helpdesk::Note.last))
    end

    def test_forward_with_user_id_valid
      user = add_test_agent(account, { role: account.roles.find_by_name("Agent").id })
      params_hash = forward_note_params_hash.merge(agent_id: user.id)
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params_hash, latest_note))
      match_json(note_pattern({}, latest_note))
    end

    def test_forward_with_user_id_invalid_privilege
      params_hash = forward_note_params_hash.merge(agent_id: other_user.id)
      controller.class.any_instance.stubs(:is_allowed_to_assume?).returns(false)
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 403
      match_json(request_error_pattern('invalid_user', id: other_user.id, name: other_user.name))
      controller.class.any_instance.unstub(:is_allowed_to_assume?)
    end

    def test_forward_numericality_invalid
      params_hash = { agent_id: 'x', body: Faker::Lorem.paragraph, to_emails: [Faker::Internet.email] }
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('agent_id', :datatype_mismatch, expected_data_type: 'Positive Integer', prepend_msg: :input_received, given_data_type: String)])
    end

    def test_forward_datatype_invalid
      params_hash = { to_emails: 'x', cc_emails: 'x', attachments: 'x', bcc_emails: 'x', body: Faker::Lorem.paragraph }
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('to_emails', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                  bad_request_error_pattern('cc_emails', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                  bad_request_error_pattern('attachments', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                  bad_request_error_pattern('bcc_emails', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String)])
    end

    def test_forward_email_format_invalid
      params_hash = { to_emails: ['dj#'], cc_emails: ['tyt@'], bcc_emails: ['hj#'], from_email: 'dg#', body: Faker::Lorem.paragraph }
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('to_emails', :array_invalid_format, accepted: 'valid email address'),
                  bad_request_error_pattern('cc_emails', :array_invalid_format, accepted: 'valid email address'),
                  bad_request_error_pattern('bcc_emails', :array_invalid_format, accepted: 'valid email address'),
                  bad_request_error_pattern('from_email', :invalid_format, accepted: 'valid email address')])
    end

    def test_forward_invalid_id
      params_hash = { body: 'test', to_emails: [Faker::Internet.email] }
      post :forward, construct_params({version: 'private', id: '6786878' }, params_hash)
      assert_response :missing
    end

    def test_forward_invalid_model
      params_hash = { body: 'test', agent_id: 789_789_789, to_emails: [Faker::Internet.email] }
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('agent_id', :absent_in_db, resource: :agent, attribute: :agent_id)])
    end

    def test_forward_invalid_from_email
      params_hash = { body: 'test', to_emails: [Faker::Internet.email], from_email: Faker::Internet.email }
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('from_email', :absent_in_db, resource: :"active email_config", attribute: :from_email)])
    end

    def test_forward_new_email_config
      email_config = create_email_config
      params_hash = forward_note_params_hash.merge(from_email: email_config.reply_email)
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      note = Helpdesk::Note.last
      assert_equal email_config.id, note.email_config_id 
      match_json(note_pattern(params_hash, note))
      match_json(note_pattern({}, note))
    end

    def test_forward_inactive_email_config
      email_config = create_email_config
      email_config.active = false
      email_config.save
      params_hash = forward_note_params_hash.merge(from_email: email_config.reply_email)
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('from_email', :absent_in_db, resource: :"active email_config", attribute: :from_email)])
    end

    def test_forward_extra_params
      params_hash = { body_html: 'test', junk: 'test', to_emails: [Faker::Internet.email] }
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('junk', :invalid_field), bad_request_error_pattern('body_html', :invalid_field)])
    end

    def test_forward_invalid_agent
      user = add_new_user(account)
      params_hash = forward_note_params_hash.merge(agent_id: user.id)
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('agent_id', :absent_in_db, resource: :agent, attribute: :agent_id)])
    end

    def test_forward_with_attachment
      t = create_ticket
      file = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
      file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
      params = forward_note_params_hash.merge('attachments' => [file, file2])
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      post :forward, construct_params({version: 'private', id: t.display_id }, params)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 201
      response_params = params.except(:attachments)
      match_json(note_pattern(params, Helpdesk::Note.last))
      match_json(note_pattern({}, Helpdesk::Note.last))
      assert Helpdesk::Note.last.attachments.count == 2
    end

    def test_forward_with_ticket_with_attachment
      t = create_ticket({ attachments: { resource: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) } })
      params = forward_note_params_hash
      post :forward, construct_params({version: 'private', id: t.display_id }, params)
      assert_response 201
      match_json(note_pattern(params, Helpdesk::Note.last))
      match_json(note_pattern({}, Helpdesk::Note.last))
      assert Helpdesk::Note.last.attachments.count == 1
    end

    def test_forward_with_ticket_with_cloud_attachment
      t = create_ticket({ cloud_files:  [Helpdesk::CloudFile.new({ filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 })] })
      params = forward_note_params_hash
      post :forward, construct_params({version: 'private', id: t.display_id }, params)
      assert_response 201
      match_json(note_pattern(params, Helpdesk::Note.last))
      match_json(note_pattern({}, Helpdesk::Note.last))
      assert Helpdesk::Note.last.cloud_files.count == 1
    end

    def test_forward_with_attachments_invalid_size
      Rack::Test::UploadedFile.any_instance.stubs(:size).returns(20_000_000)
      file = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
      params = forward_note_params_hash.merge('attachments' => [file])
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 400
      match_json([bad_request_error_pattern('attachments', :invalid_size, max_size: '15 MB', current_size: '19.1 MB')])
    end

    def test_forward_with_invalid_attachment_params_format
      params = forward_note_params_hash.merge('attachments' => [1, 2])
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params)
      assert_response 400
      match_json([bad_request_error_pattern('attachments', :array_datatype_mismatch, expected_data_type: 'valid file format')])
    end

    def test_forward_without_privilege
      User.any_instance.stubs(:privilege?).with(:forward_ticket).returns(false).at_most_once
      params_hash = forward_note_params_hash
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      User.any_instance.unstub(:privilege?)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    end

    def test_forward_without_quoted_text_and_empty_body
      params = forward_note_params_hash.merge(include_quoted_text: false)
      params.delete(:body)
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params)
      assert_response 400
      match_json([bad_request_error_pattern('body', :missing_field)])
    end

    def test_forward_without_quoted_text
      params = forward_note_params_hash.merge(include_quoted_text: false)
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params, latest_note))
      match_json(note_pattern({}, latest_note))
    end

    def test_forward_with_invalid_draft_attachment_ids
      attachment_ids = []
      attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      invalid_ids = [attachment_ids.last + 10, attachment_ids.last + 20]
      params_hash = forward_note_params_hash.merge({attachment_ids: (attachment_ids | invalid_ids)})
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern(:attachment_ids, :invalid_list, list: invalid_ids.join(', '))])
    end

    def test_forward_with_draft_attachment_ids
      attachment_ids = []
      rand(2..10).times do
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      end
      params_hash = forward_note_params_hash.merge({attachment_ids: attachment_ids, agent_id: @agent.id})
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params_hash, latest_note))
      match_json(note_pattern({}, latest_note))
      assert latest_note.attachments.size == attachment_ids.size
    end

    def test_forward_without_original_attachments
      t = create_ticket({ attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) } })
      params = forward_note_params_hash.merge(include_original_attachments: false)
      post :forward, construct_params({version: 'private', id: t.display_id }, params)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params, latest_note))
      match_json(note_pattern({}, latest_note))
      assert latest_note.attachments.count == 0
    end

    def test_forward_with_ticket_attachment_ids
      t = create_ticket(attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) })
      params = forward_note_params_hash.merge(include_original_attachments: false, attachment_ids: [t.attachments.first.id])
      post :forward, construct_params({version: 'private', id: t.display_id }, params)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params, latest_note))
      match_json(note_pattern({}, latest_note))
      assert latest_note.attachments.count == 1
    end

    def test_forward_dup_removal_of_attachments
      t = create_ticket(attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) })
      create_shared_attachment(t)
      attachment_ids = t.all_attachments.map(&:id)
      params = forward_note_params_hash.merge(include_original_attachments: true, attachment_ids: attachment_ids)
      post :forward, construct_params({version: 'private', id: t.display_id }, params)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params, latest_note))
      match_json(note_pattern({}, latest_note))
      assert latest_note.attachments.count == 2
    end

    def test_forward_with_attachment_and_draft_attachment_ids
      t = create_ticket
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      file1 = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
      file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
      attachments = [file1, file2]
      params_hash = forward_note_params_hash.merge({agent_id: @agent.id, attachment_ids: [attachment_id], attachments: attachments})
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data' 
      post :forward, construct_params({version: 'private', id: t.display_id }, params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params_hash, latest_note))
      match_json(note_pattern({}, latest_note))
      assert latest_note.attachments.size == (attachments.size + 1)
    end

    def test_forward_with_cloud_file_ids_error
      params = forward_note_params_hash.merge(include_original_attachments: true, cloud_file_ids: [100, 200])
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params)
      assert_response 400
      match_json([bad_request_error_pattern('cloud_file_ids', :included_original_attachments, code: :incompatible_field)])
    end

    def test_forward_with_invalid_cloud_file_ids
      latest_cloud_file = Helpdesk::CloudFile.last.try(:id) || 0
      invalid_ids = [latest_cloud_file + 10, latest_cloud_file + 20]
      params = forward_note_params_hash.merge(include_original_attachments: false, cloud_file_ids: invalid_ids)
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params)
      assert_response 400
      match_json([bad_request_error_pattern(:cloud_file_ids, :invalid_list, list: invalid_ids.join(', '))])
    end

    def test_forward_with_cloud_file_ids
      t = create_ticket({ cloud_files:  [Helpdesk::CloudFile.new({ filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 }),
                                         Helpdesk::CloudFile.new({ filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 })] })
      params = forward_note_params_hash.merge(include_original_attachments: false, cloud_file_ids: [t.cloud_files.first.id])
      post :forward, construct_params({version: 'private', id: t.display_id }, params)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params, latest_note))
      match_json(note_pattern({}, latest_note))
      assert latest_note.cloud_files.count == 1
    end

    def test_forward_with_all_attachments_and_attachment_ids
      draft_attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      file1 = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
      file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
      new_attachments = [file1, file2]
      t = create_ticket({ attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) },
                          cloud_files:  [Helpdesk::CloudFile.new({ filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 })] })
      create_shared_attachment(t)
      params = forward_note_params_hash.merge(include_original_attachments: true, 
                attachments: new_attachments, attachment_ids: [draft_attachment_id])
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      post :forward, construct_params({version: 'private', id: t.display_id }, params)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params, latest_note))
      match_json(note_pattern({}, latest_note))
      assert latest_note.attachments.count == 5
      assert latest_note.cloud_files.count == 1
    end

    def test_forward_with_cloud_files_upload
      t = create_ticket
      cloud_file_params = [{ filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 },
                           { filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 }]
      params = forward_note_params_hash.merge(cloud_files: cloud_file_params)
      post :forward, construct_params({version: 'private', id: t.display_id }, params)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params, latest_note))
      match_json(note_pattern({}, latest_note))
      assert latest_note.cloud_files.count == 2
    end

    def test_forward_with_invalid_cloud_files
      t = create_ticket
      cloud_file_params = [{ filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 10000 }]
      params = forward_note_params_hash.merge(cloud_files: cloud_file_params)
      post :forward, construct_params({version: 'private', id: t.display_id }, params)
      assert_response 400
      match_json([bad_request_error_pattern(:application_id, :invalid_list, list: '10000')])
    end

    def test_forward_with_existing_and_new_cloud_files
      t = create_ticket({ cloud_files:  [Helpdesk::CloudFile.new({ filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 }),
                                         Helpdesk::CloudFile.new({ filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 })] })
      cloud_file_params = [{ filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 }]
      params = forward_note_params_hash.merge(cloud_files: cloud_file_params)
      post :forward, construct_params({version: 'private', id: t.display_id }, params)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params, latest_note))
      match_json(note_pattern({}, latest_note))
      assert latest_note.cloud_files.count == 3
    end

    def test_forward_with_shared_attachments
      canned_response = create_response(
          title: Faker::Lorem.sentence,
          content_html: Faker::Lorem.paragraph,
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) })
      params = forward_note_params_hash.merge(attachment_ids: canned_response.shared_attachments.map(&:attachment_id))
      post :forward, construct_params({version: 'private', id: create_ticket.display_id }, params)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params, latest_note))
      match_json(note_pattern({}, latest_note))
      assert latest_note.attachments.count == 1
    end

    def test_ticket_conversations_with_fone_call
      # while creating freshfone account during tests MixpanelWrapper was throwing error, so stubing that
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      ticket = new_ticket_from_call
      remove_wrap_params
      assert ticket.notes.all.map { |n| n.freshfone_call.present? || nil }.compact.present?
      get :ticket_conversations, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 200
      match_json(conversations_pattern(ticket))
      MixpanelWrapper.unstub(:send_to_mixpanel)
    end

    def test_facebook_reply_without_params
      ticket = create_ticket_from_fb_post
      post :facebook_reply, construct_params({version: 'private', id: ticket.display_id}, {})
      assert_response 400
      match_json([bad_request_error_pattern('body', :datatype_mismatch, code: :missing_field, expected_data_type: String)])
    end

    def test_facebook_reply_with_invalid_ticket
      ticket = create_ticket
      params_hash = { body: Faker::Lorem.paragraph }
      post :facebook_reply, construct_params({version: 'private', id: ticket.display_id}, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('ticket_id', :not_a_facebook_ticket)])
    end

    def test_facebook_reply_with_invalid_note_id
      ticket = create_ticket_from_fb_post
      invalid_id = (Helpdesk::Note.last.try(:id) || 0) + 10
      params_hash = { body: Faker::Lorem.paragraph, note_id: invalid_id}
      post :facebook_reply, construct_params({version: 'private', id: ticket.display_id}, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('note_id', :absent_in_db, resource: :note, attribute: :note_id)])
    end

    def test_facebook_reply_to_fb_post_ticket
      ticket = create_ticket_from_fb_post
      put_comment_id = "#{(Time.now.ago(2.minutes).utc.to_f*100000).to_i}_#{(Time.now.ago(6.minutes).utc.to_f*100000).to_i}"
      sample_put_comment = { "id" => put_comment_id }
      Koala::Facebook::API.any_instance.stubs(:put_comment).returns(sample_put_comment)
      params_hash = { body: Faker::Lorem.paragraph }
      post :facebook_reply, construct_params({version: 'private', id: ticket.display_id}, params_hash)
      Koala::Facebook::API.any_instance.unstub(:put_comment)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params_hash, latest_note))
    end

    def test_facebook_reply_to_fb_comment_note
      ticket = create_ticket_from_fb_post(true)
      put_comment_id = "#{(Time.now.ago(2.minutes).utc.to_f*100000).to_i}_#{(Time.now.ago(6.minutes).utc.to_f*100000).to_i}"
      sample_put_comment = { "id" => put_comment_id }
      fb_comment_note = ticket.notes.where(source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["facebook"]).first
      Koala::Facebook::API.any_instance.stubs(:put_comment).returns(sample_put_comment)
      params_hash = { body: Faker::Lorem.paragraph, note_id: fb_comment_note.id }
      post :facebook_reply, construct_params({version: 'private', id: ticket.display_id}, params_hash)
      Koala::Facebook::API.any_instance.unstub(:put_comment)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params_hash, latest_note))
    end

    def test_facebook_reply_to_fb_direct_message_ticket
      ticket = create_ticket_from_fb_direct_message
      sample_reply_dm = { "id" => Time.now.utc.to_i + 5 }
      Koala::Facebook::API.any_instance.stubs(:put_object).returns(sample_reply_dm)
      params_hash = { body: Faker::Lorem.paragraph }
      post :facebook_reply, construct_params({version: 'private', id: ticket.display_id}, params_hash)
      Koala::Facebook::API.any_instance.unstub(:put_object)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params_hash, latest_note))
    end

    def test_facebook_reply_to_non_fb_post_note
      ticket = create_ticket_from_fb_direct_message
      fb_dm_note = ticket.notes.where(source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["facebook"]).first
      params_hash = { body: Faker::Lorem.paragraph, note_id: fb_dm_note.id }
      post :facebook_reply, construct_params({version: 'private', id: ticket.display_id}, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('note_id', :unable_to_post_reply)])
    end

    def test_facebook_reply_to_non_commentable_note
      ticket = create_ticket_from_fb_post(true, true)
      fb_comment_note = ticket.notes.where(source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["facebook"]).last
      params_hash = { body: Faker::Lorem.paragraph, note_id: fb_comment_note.id }
      post :facebook_reply, construct_params({version: 'private', id: ticket.display_id}, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('note_id', :unable_to_post_reply)])
    end

    def test_facebook_reply_with_invalid_agent_id
      user = add_new_user(account)
      ticket = create_ticket_from_fb_direct_message
      params_hash = { body: Faker::Lorem.paragraph, agent_id: user.id }
      post :facebook_reply, construct_params({version: 'private', id: ticket.display_id}, params_hash)
      assert_response 400
      match_json([bad_request_error_pattern('agent_id', :absent_in_db, resource: :agent, attribute: :agent_id)])
    end

    def test_facebook_reply_with_valid_agent_id
      user = add_test_agent(account, { role: account.roles.find_by_name("Agent").id })
      ticket = create_ticket_from_fb_direct_message
      sample_reply_dm = { "id" => Time.now.utc.to_i + 5 }
      Koala::Facebook::API.any_instance.stubs(:put_object).returns(sample_reply_dm)
      params_hash = { body: Faker::Lorem.paragraph, agent_id: user.id }
      post :facebook_reply, construct_params({version: 'private', id: ticket.display_id}, params_hash)
      Koala::Facebook::API.any_instance.unstub(:put_object)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params_hash, latest_note))
      match_json(note_pattern({}, latest_note))
    end

    def test_tweet_reply_without_params
      ticket = create_twitter_ticket
      post :tweet, construct_params({version: 'private', id: ticket.display_id}, {})
      assert_response 400
      match_json([
        bad_request_error_pattern('body', :datatype_mismatch, code: :missing_field, expected_data_type: String),
        bad_request_error_pattern('tweet_type', :datatype_mismatch, code: :missing_field, expected_data_type: String),
        bad_request_error_pattern('twitter_handle_id', :datatype_mismatch, code: :missing_field, expected_data_type: 'Positive Integer')
      ])
    end

    def test_tweet_reply_with_invalid_ticket
      ticket = create_ticket
      post :tweet, construct_params({version: 'private', id: ticket.display_id}, { 
        body: Faker::Lorem.sentence[0..130], 
        tweet_type: 'dm', 
        twitter_handle_id: get_twitter_handle.id 
      })
      assert_response 400
      match_json([bad_request_error_pattern('ticket_id', :not_a_twitter_ticket)])
    end

    def test_twitter_reply_to_tweet_ticket
      ticket = create_twitter_ticket
      twitter_object = sample_twitter_object
      twitter_handle = get_twitter_handle

      @account = Account.current
      @default_stream = twitter_handle.default_stream
      Twitter::REST::Client.any_instance.stubs(:update).returns(twitter_object)
      
      unless GNIP_ENABLED
        Social::DynamoHelper.stubs(:update).returns(dynamo_update_attributes(twitter_object[:id]))
        Social::DynamoHelper.stubs(:get_item).returns(sample_dynamo_get_item_params)
      end
      
      params_hash = {
        body: Faker::Lorem.sentence[0..130],
        tweet_type: 'mention',
        twitter_handle_id: twitter_handle.id
      }
      post :tweet, construct_params({version: 'private', id: ticket.display_id}, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params_hash, latest_note))
      
      Twitter::REST::Client.any_instance.unstub(:update)
      
      unless GNIP_ENABLED
        Social::DynamoHelper.unstub(:update)
        Social::DynamoHelper.unstub(:get_item)
      end
      
    end

    def test_twitter_dm_reply_to_tweet_ticket
      ticket = create_twitter_ticket
      twitter_object = sample_twitter_object
      twitter_handle = get_twitter_handle
      
      dm_text = Faker::Lorem.paragraphs(5).join[0..500]
      @account = Account.current
      @default_stream = twitter_handle.default_stream
      
      reply_id = get_social_id
      dm_reply_params = {
        :id => reply_id,
        :id_str => "#{reply_id}",
        :recipient_id_str => rand.to_s[2..11],
        :text => dm_text ,
        :created_at => "#{Time.zone.now}"
      }
      sample_dm_reply = Twitter::DirectMessage.new(dm_reply_params)
      Twitter::REST::Client.any_instance.stubs(:create_direct_message).returns(sample_dm_reply)

      unless GNIP_ENABLED
        Social::DynamoHelper.stubs(:insert).returns({})
        Social::DynamoHelper.stubs(:update).returns({})
      end

      params_hash = {
        body: Faker::Lorem.sentence[0..130],
        tweet_type: 'dm',
        twitter_handle_id: twitter_handle.id
      }
      post :tweet, construct_params({version: 'private', id: ticket.display_id}, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(note_pattern(params_hash, latest_note))
      
      Twitter::REST::Client.any_instance.unstub(:create_direct_message)

      unless GNIP_ENABLED
        Social::DynamoHelper.unstub(:insert)
        Social::DynamoHelper.unstub(:update)
      end

    end

    def test_ticket_conversations
      t = create_ticket
      create_private_note(t)
      create_reply_note(t)
      create_forward_note(t)
      create_feedback_note(t)
      create_fb_note(t)
      create_twitter_note(t)
      get :ticket_conversations, controller_params(version: 'private', id: t.display_id)
      assert_response 200
      response = parse_response @response.body
      assert_equal 6, response.size
    end

    def test_update_without_ticket_access
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      t = create_ticket
      note = create_private_note(t)
      put :update, construct_params({ version: 'private', id: note.id }, update_note_params_hash)
      assert_response 403
      match_json(request_error_pattern(:access_denied))
      User.any_instance.unstub(:has_ticket_permission?)
    end

    def test_update_success
      t = create_ticket
      note = create_private_note(t)
      params_hash = update_note_params_hash
      put :update, construct_params({ version: 'private', id: note.id }, params_hash)
      assert_response 200
      note = Helpdesk::Note.find(note.id)
      match_json(update_note_pattern(params_hash, note))
      match_json(update_note_pattern({}, note))
    end

    def test_update_with_attachments
      file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      canned_response = create_response(
          title: Faker::Lorem.sentence,
          content_html: Faker::Lorem.paragraph,
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) })
      params_hash = update_note_params_hash.merge('attachments' => [file], 
          'attachment_ids' => [attachment_id] | canned_response.shared_attachments.map(&:attachment_id))
      t = create_ticket
      note = create_private_note(t)
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      put :update, construct_params({ version: 'private', id: note.id }, params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 200
      note = Helpdesk::Note.find(note.id)
      match_json(update_note_pattern(params_hash, note))
      match_json(update_note_pattern({}, note))
      assert_equal 3, note.attachments.count
    end

    def test_update_with_cloud_files
      cloud_file_params = [{ filename: 'image.jpg', url: 'https://www.dropbox.com/image.jpg', application_id: 20 }]
      params_hash = update_note_params_hash.merge(cloud_files: cloud_file_params)
      t = create_ticket
      note = create_private_note(t)
      put :update, construct_params({ version: 'private', id: note.id }, params_hash)
      assert_response 200
      note = Helpdesk::Note.find(note.id)
      match_json(update_note_pattern(params_hash, note))
      match_json(update_note_pattern({}, note))
      assert_equal 1, note.cloud_files.count
    end
    
    def test_agent_reply_template_with_empty_signature
      remove_wrap_params
      t = create_ticket

      notification_template = "<div>{{ticket.id}}</div>"
      Agent.any_instance.stubs(:signature_value).returns('')
      EmailNotification.any_instance.stubs(:get_reply_template).returns(notification_template)

      get :reply_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200
      match_json(reply_template_pattern({
          template: "<div>#{t.display_id}</div>",
          signature: ''
        }))

      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_reply_template)
      
    end
    
    def test_agent_reply_template_with_signature
      remove_wrap_params
      t = create_ticket

      notification_template = "<div>{{ticket.id}}</div>"
      agent_signature = "<div><p>Thanks</p><p>{{ticket.subject}}</p></div>"
      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:get_reply_template).returns(notification_template)

      get :reply_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200
      
      match_json(reply_template_pattern({
          template: "<div>#{t.display_id}</div>",
          signature: "<div><p>Thanks</p><p>#{t.subject}</p></div>"
        }))
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
      match_json(reply_template_pattern(template: '', signature: ''))

      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:present?)
    end
    
    
    def test_agent_forward_emplate_with_empty_template_and_with_signature
      t = create_ticket

      agent_signature = "<div><p>Thanks</p><p>{{ticket.subject}}</p></div>"
      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:present?).returns(false)
      EmailNotification.any_instance.stubs(:get_forward_template).returns('')

      get :forward_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200
      match_json(reply_template_pattern({
        template: '',
        signature: "<div><p>Thanks</p><p>#{t.subject}</p></div>"
        }))

      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:present?)
    end
    
    def test_agent_forward_template_with_empty_signature
      remove_wrap_params
      t = create_ticket

      notification_template = "<div>{{ticket.id}}</div>"

      Agent.any_instance.stubs(:signature_value).returns('')
      EmailNotification.any_instance.stubs(:get_forward_template).returns(notification_template)

      get :forward_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200
      match_json(reply_template_pattern({
          template: "<div>#{t.display_id}</div>",
          signature: ''
        }))
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_forward_template)
    end
    
    def test_agent_forward_template_with_signature
      remove_wrap_params
      t = create_ticket
      
      notification_template = "<div>{{ticket.id}}</div>"
      agent_signature = "<div><p>Thanks</p><p>{{ticket.subject}}</p></div>"
      
      Agent.any_instance.stubs(:signature_value).returns(agent_signature)
      EmailNotification.any_instance.stubs(:get_forward_template).returns(notification_template)

      get :forward_template, construct_params({ version: 'private', id: t.display_id }, false)
      assert_response 200
      
      match_json(reply_template_pattern({
          template: "<div>#{t.display_id}</div>",
          signature: "<div><p>Thanks</p><p>#{t.subject}</p></div>"
        }))
        
      Agent.any_instance.unstub(:signature_value)
      EmailNotification.any_instance.unstub(:get_forward_template)
      
    end
  end
end
