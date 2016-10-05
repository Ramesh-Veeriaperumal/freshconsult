require_relative '../../test_helper'
module Ember
  class ConversationsControllerTest < ActionController::TestCase
    include ConversationsTestHelper
    include AttachmentsTestHelper

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
      file1 = fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)
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
      file1 = fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)
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
  end
end
