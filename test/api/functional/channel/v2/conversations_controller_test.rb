require_relative '../../../test_helper'
module Channel::V2
  class ConversationsControllerTest < ActionController::TestCase
    include ConversationsTestHelper
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
  end
end
