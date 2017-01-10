require_relative '../../test_helper'
module Pipe
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
      body = Faker::Lorem.paragraph
      agent_email1 = Agent.last.user.email
      agent_email2 = Agent.find { |x| x.user.email != agent_email1 }.try(:user).try(:email) || add_test_agent(@account, role: Role.find_by_name('Agent').id).email
      email = [agent_email1, agent_email2]
      params_hash = { body: body, notify_emails: email, private: true }
      params_hash
    end

    def test_create_with_created_at_updated_at
      created_at = updated_at = Time.now
      params_hash = create_note_params_hash.merge('created_at' => created_at,
                                                  'updated_at' => updated_at)
      post :create, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 201
      note = Helpdesk::Note.last
      match_json(note_pattern(params_hash, note))
      match_json(note_pattern({}, note))
      assert (note.created_at - created_at).to_i == 0
      assert (note.updated_at - updated_at).to_i == 0
    end
  end
end
