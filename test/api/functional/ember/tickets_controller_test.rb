require_relative '../../test_helper'
module Ember
  class TicketsControllerTest < ActionController::TestCase
    include TicketsTestHelper
    include ScenarioAutomationsTestHelper
    include AttachmentsTestHelper
    include CannedResponsesTestHelper

    def setup
      super
      before_all
    end

    @@before_all_run = false
    def before_all
      return if @@before_all_run
      @account.ticket_fields.custom_fields.each(&:destroy)
      @@custom_field = create_custom_field(Faker::Lorem.word, 'text')
      @@custom_field.update_attribute(:required_for_closure, true)
      @@before_all_run = true
    end

    def wrap_cname(params)
      { ticket: params }
    end

    def ticket_params_hash
      cc_emails = [Faker::Internet.email, Faker::Internet.email]
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      email = Faker::Internet.email
      tags = [Faker::Name.name, Faker::Name.name]
      @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
      params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                      priority: 2, status: 2, type: 'Problem', responder_id: @agent.id, source: 1, tags: tags,
                      due_by: 14.days.since.iso8601, fr_due_by: 1.days.since.iso8601, group_id: @create_group.id }
      params_hash
    end

    def update_ticket_params_hash
      agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      subject = Faker::Lorem.words(10).join(' ')
      description = Faker::Lorem.paragraph
      @update_group ||= create_group_with_agents(@account, agent_list: [agent.id])
      params_hash = { description: description, subject: subject, priority: 4, status: 7, type: 'Incident',
                      responder_id: agent.id, source: 3, tags: ['update_tag1', 'update_tag2'],
                      due_by: 12.days.since.iso8601, fr_due_by: 4.days.since.iso8601, group_id: @update_group.id }
      params_hash
    end

    def test_create_with_incorrect_attachment_type
      attachment_ids = ['A', 'B', 'C']
      params_hash = ticket_params_hash.merge({attachment_ids: attachment_ids})
      post :create, construct_params({version: 'private'}, params_hash)
      match_json([bad_request_error_pattern(:attachment_ids, :array_datatype_mismatch, expected_data_type: 'Positive Integer')])
      assert_response 400
    end

    def test_create_with_invalid_attachment_ids
      attachment_ids = []
      attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      invalid_ids = [attachment_ids.last + 10, attachment_ids.last + 20]
      params_hash = ticket_params_hash.merge({attachment_ids: (attachment_ids | invalid_ids)})
      post :create, construct_params({version: 'private'}, params_hash)
      match_json([bad_request_error_pattern(:attachment_ids, :invalid_list, list: invalid_ids.join(', '))])
      assert_response 400
    end

     def test_create_with_invalid_attachment_size
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      params_hash = ticket_params_hash.merge({attachment_ids: [attachment_id]})
      Helpdesk::Attachment.any_instance.stubs(:content_file_size).returns(20_000_000)
      post :create, construct_params({version: 'private'}, params_hash)
      Helpdesk::Attachment.any_instance.unstub(:content_file_size)
      match_json([bad_request_error_pattern(:attachment_ids, :invalid_size, max_size: '15 MB', current_size: '19.1 MB')])
      assert_response 400
    end

    def test_create_with_errors
      attachment_ids = []
      rand(2..10).times do
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      end
      params_hash = ticket_params_hash.merge({attachment_ids: attachment_ids})
      Helpdesk::Ticket.any_instance.stubs(:save).returns(false)
      post :create, construct_params({version: 'private'}, params_hash)
      Helpdesk::Ticket.any_instance.unstub(:save)
      assert_response 500
    end

    def test_create_with_attachment_ids
      attachment_ids = []
      rand(2..10).times do
        attachment_ids << create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      end
      params_hash = ticket_params_hash.merge({attachment_ids: attachment_ids})
      post :create, construct_params({version: 'private'}, params_hash)
      assert_response 201
      match_json(ticket_pattern(params_hash, Helpdesk::Ticket.last))
      match_json(ticket_pattern({}, Helpdesk::Ticket.last))
      assert Helpdesk::Ticket.last.attachments.size == attachment_ids.size
    end

    def test_create_with_attachment_and_attachment_ids
      attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
      file1 = fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)
      file2 = fixture_file_upload('files/image33kb.jpg', 'image/jpg')
      attachments = [file1, file2]
      params_hash = ticket_params_hash.merge({attachment_ids: [attachment_id], attachments: attachments})
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data' 
      post :create, construct_params({version: 'private'}, params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 201
      match_json(ticket_pattern(params_hash, Helpdesk::Ticket.last))
      match_json(ticket_pattern({}, Helpdesk::Ticket.last))
      assert Helpdesk::Ticket.last.attachments.size == (attachments.size + 1)
    end

    def test_execute_scenario_without_params
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      put :execute_scenario, construct_params({version: 'private', id: ticket_id}, {})
      assert_response 400
      match_json([bad_request_error_pattern('scenario_id', :missing_field)])
    end

    def test_execute_scenario_with_invalid_ticket_id
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id + 20
      put :execute_scenario, construct_params({version: 'private', id: ticket_id}, scenario_id: scenario_id)
      assert_response 404
    end

    def test_execute_scenario_without_ticket_access
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      put :execute_scenario, construct_params({version: 'private', id: ticket_id}, scenario_id: scenario_id)
      User.any_instance.unstub(:has_ticket_permission?)
      assert_response 403
    end

    def test_execute_scenario_without_scenario_access
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      ScenarioAutomation.any_instance.stubs(:check_user_privilege).returns(false)
      put :execute_scenario, construct_params({version: 'private', id: ticket_id}, scenario_id: scenario_id)
      ScenarioAutomation.any_instance.unstub(:check_user_privilege)
      assert_response 400
      match_json([bad_request_error_pattern('scenario_id', :inaccessible_value, resource: :scenario, attribute: :scenario_id)])
    end

    def test_execute_scenario
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_id = create_ticket(ticket_params_hash).display_id
      put :execute_scenario, construct_params({version: 'private', id: ticket_id}, scenario_id: scenario_id)
      assert_response 204
    end

    def test_bulk_execute_scenario_with_invalid_ticket_ids
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_ids = []
      rand(2..10).times do
        ticket_ids << create_ticket(ticket_params_hash).display_id
      end
      invalid_ids = [ticket_ids.last + 20, ticket_ids.last + 30]
      id_list = [*ticket_ids, *invalid_ids]
      put :bulk_execute_scenario, construct_params({ version: 'private' }, { scenario_id: scenario_id, ids: id_list })
      failures = {}
      invalid_ids.each { |id| failures[id] = { :id => :"is invalid" } }
      match_json(partial_success_response_pattern(ticket_ids, failures))
      assert_response 202
    end

    def test_bulk_execute_scenario_without_scenario_id
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_ids = []
      rand(2..10).times do
        ticket_ids << create_ticket(ticket_params_hash).display_id
      end
      put :bulk_execute_scenario, construct_params({ version: 'private' }, { ids: ticket_ids })
      assert_response 400
      match_json([bad_request_error_pattern('scenario_id', :missing_field)])
    end

    def test_bulk_execute_scenario_with_invalid_scenario_id
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_ids = []
      rand(2..10).times do
        ticket_ids << create_ticket(ticket_params_hash).display_id
      end
      put :bulk_execute_scenario, construct_params({ version: 'private' }, { scenario_id: scenario_id + 10, ids: ticket_ids })
      assert_response 400
      match_json([bad_request_error_pattern('scenario_id', :absent_in_db, resource: :scenario, attribute: :scenario_id)])
    end

    def test_bulk_execute_scenario_with_valid_ids
      scenario_id = create_scn_automation_rule(scenario_automation_params).id
      ticket_ids = []
      rand(2..10).times do
        ticket_ids << create_ticket(ticket_params_hash).display_id
      end
      put :bulk_execute_scenario, construct_params({ version: 'private' }, { scenario_id: scenario_id, ids: ticket_ids })
      assert_response 202
    end

    def test_bulk_update_with_no_params
      put :bulk_update, construct_params({ version: 'private' }, {})
      match_json([bad_request_error_pattern('ids', :missing_field),
                  bad_request_error_pattern('properties', :missing_field)])
      assert_response 400
    end

    def test_bulk_update_with_incorrect_values
      ticket_ids = []
      rand(2..4).times do
        ticket_ids << create_ticket.id
      end
      statuses = Helpdesk::TicketStatus.status_objects_from_cache(@account).map(&:status_id)
      incorrect_values = { priority: 90, status: statuses.last + 1, type: 'jksadjxyz' }
      params_hash = {ids: ticket_ids, properties: update_ticket_params_hash.merge(incorrect_values) }
      put :bulk_update, construct_params({ version: 'private' }, params_hash)
      match_json([bad_request_error_pattern('priority', :not_included, list: '1,2,3,4'),
                bad_request_error_pattern('status', :not_included, list: statuses.join(',')),
                bad_request_error_pattern('type', :not_included, list: 'Question,Incident,Problem,Feature Request')])
      assert_response 400
    end

    def test_bulk_update_with_invalid_params
      ticket_ids = []
      rand(2..4).times do
        ticket_ids << create_ticket.id
      end
      params_hash = {ids: ticket_ids, properties: update_ticket_params_hash.merge(responder_id: User.last.id + 10) }
      put :bulk_update, construct_params({ version: 'private' }, params_hash)
      match_json([bad_request_error_pattern('responder_id', :absent_in_db, resource: :agent, attribute: :responder_id)])
      assert_response 400
    end

    def test_bulk_update_with_invalid_ids
      ticket_ids = []
      rand(2..4).times do
        ticket_ids << create_ticket.id
      end
      invalid_ids = [ticket_ids.last + 10, ticket_ids.last + 20]
      params_hash = {ids: [*ticket_ids, *invalid_ids], properties: update_ticket_params_hash }
      put :bulk_update, construct_params({ version: 'private' }, params_hash)
      failures = {}
      invalid_ids.each { |id| failures[id] = { :id => :"is invalid" } }
      match_json(partial_success_response_pattern(ticket_ids, failures))
      assert_response 202
    end

    def test_bulk_update_with_custom_fields
      ticket_ids = []
      rand(2..4).times do
        ticket_ids << create_ticket.id
      end
      properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5)
      params_hash = {ids: ticket_ids, properties: properties_hash}
      put :bulk_update, construct_params({ version: 'private' }, params_hash)
      failures = {}
      ticket_ids.each {|id| failures[id] = { @@custom_field.label => [:datatype_mismatch, { code: :missing_field, expected_data_type: :String }]}}
      match_json(partial_success_response_pattern([], failures))
      assert_response 202
    end

    def test_bulk_update_success
      ticket_ids = []
      rand(2..4).times do
        ticket_ids << create_ticket.id
      end
      properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5, custom_fields: {@@custom_field.label => 'Sample text'})
      params_hash = {ids: ticket_ids, properties: properties_hash}
      put :bulk_update, construct_params({ version: 'private' }, params_hash)
      match_json(partial_success_response_pattern(ticket_ids, {}))
      assert_response 202
    end

    def test_bulk_update_async
      ticket_ids = []
      10.times do
        ticket_ids << create_ticket.id
      end
      params_hash = {ids: ticket_ids, properties: update_ticket_params_hash}
      put :bulk_update, construct_params({ version: 'private' }, params_hash)
      match_json(partial_success_response_pattern(ticket_ids, {}))
      assert_response 202
    end

    # tests for latest note
    # 1. invalid ticket id
    # 2. ticket with no permission
    # 2. with valid ticket id
    #   a. with no notes
    #   b. with a private note
    #   c. with a public note
    #   d. with a reply

    def test_latest_note_ticket_with_invalid_id
      get :latest_note, construct_params({ version: 'private', id: 0 }, false)
      assert_response 404
    end

    def test_latest_note_ticket_without_permissison
      ticket = create_ticket
      user_stub_ticket_permission
      get :latest_note, construct_params({ version: 'private', id: ticket.id }, false)
      assert_response 403
      user_unstub_ticket_permission
    end

    def test_latest_note_ticket_without_notes
      ticket = create_ticket
      get :latest_note, construct_params({ version: 'private', id: ticket.id }, false)
      assert_response 204
    end

    def test_latest_note_ticket_with_private_note
      ticket = create_ticket
      note = create_note(custom_note_params(ticket, Helpdesk::Note::SOURCE_KEYS_BY_TOKEN[:note], true))
      get :latest_note, construct_params({ version: 'private', id: ticket.id }, false)
      assert_response 200
      match_json(latest_note_response_pattern(note))
    end

    def test_latest_note_ticket_with_public_note
      ticket = create_ticket
      note = create_note(custom_note_params(ticket, Helpdesk::Note::SOURCE_KEYS_BY_TOKEN[:note]))
      get :latest_note, construct_params({ version: 'private', id: ticket.id }, false)
      assert_response 200
      match_json(latest_note_response_pattern(note))
    end

    def test_latest_note_ticket_with_reply
      ticket = create_ticket
      reply = create_note(custom_note_params(ticket, Helpdesk::Note::SOURCE_KEYS_BY_TOKEN[:email]))
      get :latest_note, construct_params({ version: 'private', id: ticket.id }, false)
      assert_response 200
      match_json(latest_note_response_pattern(reply))
    end

    # tests for split note
    # 1. invalid ticket id
    # 2. invalid note id
    # 3. ticket with no permission
    # 4. Successfull split with
    #     a. normal reply
    #     b. twitter reply
    #     c. fb reply
    # 5. error in saving ticket
    # 6. verify attachmnets moving

    def test_split_note_invalid_ticket_id
      put :split_note, construct_params({ version: 'private', id: 0, note_id: 2 }, false)
      assert_response 404
    end

    def test_split_note_invalid_note_id
      ticket = create_ticket
      put :split_note, construct_params({ version: 'private', id: ticket.id, note_id: 2 }, false)
      assert_response 404
    end

    def test_split_note_ticket_without_permission
      ticket = create_ticket
      user_stub_ticket_permission
      put :split_note, construct_params({ version: 'private', id: ticket.id, note_id: 2 }, false)
      assert_response 403
      user_unstub_ticket_permission
    end

    def test_split_note_with_normal_reply
      ticket = create_ticket
      note = create_normal_reply_for(ticket)
      put :split_note, construct_params({ version: 'private', id: ticket.id, note_id: note.id }, false)
      assert_response 200
      verify_split_note_activity(ticket, note)
    end

    def test_split_note_with_twitter_reply
      ticket, note = twitter_ticket_and_note
      put :split_note, construct_params({ version: 'private', id: ticket.id, note_id: note.id }, false)
      assert_response 200
      verify_split_note_activity(ticket, note)
    end

    def test_split_note_with_fb_reply
      ticket, note = create_fb_ticket_and_note
      put :split_note, construct_params({ version: 'private', id: ticket.id, note_id: note.id }, false)
      assert_response 200
      verify_split_note_activity(ticket, note)
    end

    def test_split_note_error_in_saving
      ticket = create_ticket
      note = create_normal_reply_for(ticket)
      @controller.stubs(:ticket_attributes).returns({})
      put :split_note, construct_params({ version: 'private', id: ticket.id, note_id: note.id }, false)
      @controller.unstub(:ticket_attributes)
      assert_response 400
    end

    def test_split_note_with_attachments
      ticket = create_ticket
      note = create_normal_reply_for(ticket)
      add_attachments_to_note(note, rand(2..5))

      attachment_ids = note.attachments.map(&:id)
      assert note.cloud_files.present?
      assert note.attachments.present?

      put :split_note, construct_params({ version: 'private', id: ticket.id, note_id: note.id }, false)
      assert_response 200
      verify_split_note_activity(ticket, note)
      verify_attachments_moving(attachment_ids)
    end

  end
end
