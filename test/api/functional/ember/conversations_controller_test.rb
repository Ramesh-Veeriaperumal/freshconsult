require_relative '../../test_helper'
module Ember
  class ConversationsControllerTest < ActionController::TestCase
    include ConversationsTestHelper
    include AttachmentsTestHelper
    include TicketsTestHelper

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
      match_json(reply_note_pattern(params_hash, Helpdesk::Note.last))
      match_json(reply_note_pattern({}, Helpdesk::Note.last))
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
      match_json(reply_note_pattern(params_hash, Helpdesk::Note.last))
      match_json(reply_note_pattern({}, Helpdesk::Note.last))
      assert Helpdesk::Note.last.attachments.size == (attachments.size + 1)
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
      match_json(forward_note_pattern(params_hash, Helpdesk::Note.last))
      match_json(forward_note_pattern({}, Helpdesk::Note.last))
    end

    def test_forward_with_user_id_valid
      user = add_test_agent(account, { role: account.roles.find_by_name("Agent").id })
      params_hash = forward_note_params_hash.merge(agent_id: user.id)
      post :forward, construct_params({version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(forward_note_pattern(params_hash, latest_note))
      match_json(forward_note_pattern({}, latest_note))
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
      match_json(forward_note_pattern(params_hash, note))
      match_json(forward_note_pattern({}, note))
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
      match_json(forward_note_pattern(params, Helpdesk::Note.last))
      match_json(forward_note_pattern({}, Helpdesk::Note.last))
      assert Helpdesk::Note.last.attachments.count == 2
    end

    def test_forward_with_ticket_with_attachment
      t = create_ticket({ attachments: { resource: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) } })
      params = forward_note_params_hash
      post :forward, construct_params({version: 'private', id: t.display_id }, params)
      assert_response 201
      match_json(forward_note_pattern(params, Helpdesk::Note.last))
      match_json(forward_note_pattern({}, Helpdesk::Note.last))
      assert Helpdesk::Note.last.attachments.count == 1
    end

    def test_forward_with_ticket_with_cloud_attachment
      t = create_ticket({ cloud_files:  [Helpdesk::CloudFile.new({ filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 })] })
      params = forward_note_params_hash
      post :forward, construct_params({version: 'private', id: t.display_id }, params)
      assert_response 201
      match_json(forward_note_pattern(params, Helpdesk::Note.last))
      match_json(forward_note_pattern({}, Helpdesk::Note.last))
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
      match_json(forward_note_pattern(params, latest_note))
      match_json(forward_note_pattern({}, latest_note))
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
      match_json(forward_note_pattern(params_hash, latest_note))
      match_json(forward_note_pattern({}, latest_note))
      assert latest_note.attachments.size == attachment_ids.size
    end

    def test_forward_without_original_attachments
      t = create_ticket({ attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) } })
      params = forward_note_params_hash.merge(include_original_attachments: false)
      post :forward, construct_params({version: 'private', id: t.display_id }, params)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(forward_note_pattern(params, latest_note))
      match_json(forward_note_pattern({}, latest_note))
      assert latest_note.attachments.count == 0
    end

    def test_forward_with_ticket_attachment_ids
      t = create_ticket(attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary),
                                       resource: fixture_file_upload('files/image33kb.jpg', 'image/jpg') })
      params = forward_note_params_hash.merge(include_original_attachments: false, attachment_ids: [t.attachments.first.id])
      post :forward, construct_params({version: 'private', id: t.display_id }, params)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(forward_note_pattern(params, latest_note))
      match_json(forward_note_pattern({}, latest_note))
      assert latest_note.attachments.count == 1
    end

    def test_forward_with_original_attachments_and_invalid_attachment_ids
      t = create_ticket(attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary),
                                       resource: fixture_file_upload('files/image33kb.jpg', 'image/jpg') })
      invalid_ids = t.attachments.map(&:id)
      params = forward_note_params_hash.merge(include_original_attachments: true, attachment_ids: invalid_ids)
      post :forward, construct_params({version: 'private', id: t.display_id }, params)
      assert_response 400
      match_json([bad_request_error_pattern(:attachment_ids, :invalid_list, list: invalid_ids.join(', '))])
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
      match_json(forward_note_pattern(params_hash, latest_note))
      match_json(forward_note_pattern({}, latest_note))
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
      match_json(forward_note_pattern(params, latest_note))
      match_json(forward_note_pattern({}, latest_note))
      assert latest_note.cloud_files.count == 1
    end

    def test_forward_with_all_attachments_and_attachment_ids
      draft_attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      file1 = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
      file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
      new_attachments = [file1, file2]
      t = create_ticket({ attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) },
                          cloud_files:  [Helpdesk::CloudFile.new({ filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 })] })
      params = forward_note_params_hash.merge(include_original_attachments: true, 
                attachments: new_attachments, attachment_ids: [draft_attachment_id])
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      post :forward, construct_params({version: 'private', id: t.display_id }, params)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 201
      latest_note = Helpdesk::Note.last
      match_json(forward_note_pattern(params, latest_note))
      match_json(forward_note_pattern({}, latest_note))
      assert latest_note.attachments.count == 4
      assert latest_note.cloud_files.count == 1
    end


    def test_ticket_conversations_with_fone_call
      ticket = new_ticket_from_call
      remove_wrap_params
      assert ticket.notes.all.map { |n| n.freshfone_call.present? || nil }.compact.present?
      get :ticket_conversations, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 200
      match_json(conversations_pattern(ticket))
    end
  end
end
