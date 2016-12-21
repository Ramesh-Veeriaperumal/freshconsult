require_relative '../../test_helper'
['canned_responses_helper.rb', 'group_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module Ember
  class TicketsControllerTest < ActionController::TestCase
    include TicketsTestHelper
    include ScenarioAutomationsTestHelper
    include AttachmentsTestHelper
    include GroupHelper
    include CannedResponsesHelper
    include CannedResponsesTestHelper
    include SurveysTestHelper

    CUSTOM_FIELDS = %w(number checkbox decimal text paragraph dropdown country state city date)

    def setup
      super
      Sidekiq::Worker.clear_all
      before_all
    end

    @@before_all_run = false

    def before_all
      @account.sections.map(&:destroy)
      return if @@before_all_run
      @account.features.freshfone.create
      @account.features.forums.create
      @account.ticket_fields.custom_fields.each(&:destroy)
      Helpdesk::TicketStatus.find(2).update_column(:stop_sla_timer, false)
      @@ticket_fields = []
      @@custom_field_names = []
      @@ticket_fields << create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
      @@ticket_fields << create_custom_field_dropdown('test_custom_dropdown', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'])
      @@choices_custom_field_names = @@ticket_fields.map(&:name)
      CUSTOM_FIELDS.each do |custom_field|
        next if %w(dropdown country state city).include?(custom_field)
        @@ticket_fields << create_custom_field("test_custom_#{custom_field}", custom_field)
        @@custom_field_names << @@ticket_fields.last.name
      end
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
      tags = [Faker::Lorem.word, Faker::Lorem.word]
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

    def test_index_with_invalid_filter_id
      get :index, controller_params(version: 'private', filter: @account.ticket_filters.last.id + 10)
      assert_response 400
      match_json([bad_request_error_pattern(:filter, :absent_in_db, resource: :ticket_filter, attribute: :filter)])
    end

    def test_index_with_invalid_filter_names
      get :index, controller_params(version: 'private', filter: Faker::Lorem.word)
      assert_response 400
      valid_filters = ["spam", "deleted", "overdue", "pending", "open", "due_today", "new", "new_and_my_open", "all_tickets", "unresolved", "article_feedback", "my_article_feedback", "watching", "on_hold", "raised_by_me"]
      match_json([bad_request_error_pattern(:filter, :not_included, list: valid_filters.join(', '))])
    end

    def test_index_with_invalid_query_hash
      get :index, controller_params(version: 'private', query_hash: Faker::Lorem.word)
      assert_response 400
      match_json([bad_request_error_pattern(:query_hash, :datatype_mismatch, expected_data_type: 'key/value pair', given_data_type: String, prepend_msg: :input_received)])
    end

    def test_index_with_no_params
      ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page].times { |i| create_ticket }
      get :index, controller_params(version: 'private')
      assert_response 200
      match_json(private_api_ticket_index_pattern)
    end

    def test_index_with_filter_id
      ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page].times { |i| create_ticket(priority: 4) }
      ticket_filter = @account.ticket_filters.find_by_name('Urgent and High priority Tickets')
      get :index, controller_params(version: 'private', filter: ticket_filter.id)
      assert_response 200
      match_json(private_api_ticket_index_pattern)
    end

    def test_index_with_filter_name
      ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page].times { |i| create_ticket(requester_id: @agent.id) }
      get :index, controller_params(version: 'private', filter: 'raised_by_me')
      assert_response 200
      match_json(private_api_ticket_index_pattern)
    end

    def test_index_with_query_hash
      ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page].times { |i| create_ticket(priority: 2, requester_id: @agent.id) }
      query_hash_params = {
                            '0' => {'condition' => 'priority', 'operator' => 'is', 'value' => 2, 'type' => 'default'},
                            '1' => {'condition' => 'requester_id', 'operator' => 'is_in', 'value' => [@agent.id], 'type' => 'default'}
                          }
      get :index, controller_params({ version: 'private', query_hash: query_hash_params }, false)
      assert_response 200
      match_json(private_api_ticket_index_pattern)
    end

    def test_index_with_survey_result
      ticket = create_ticket
      result = []
      3.times do
        result << create_survey_result(ticket, 3)
      end
      get :index, controller_params(version: 'private', include: 'survey')
      assert_response 200
      match_json(private_api_ticket_index_pattern(ticket.id => result.last))
    end

    def test_index_without_survey_enabled
      ticket = create_ticket
      Account.any_instance.stubs(:features?).with(:default_survey).returns(false)
      Account.any_instance.stubs(:features?).with(:custom_survey).returns(false)
      get :index, controller_params(version: 'private', include: 'survey')
      assert_response 400
      match_json([bad_request_error_pattern('include', :require_feature, feature: 'Custom survey')])
      Account.any_instance.unstub(:features?)
    end

    def test_show_with_survey_result
      ticket = create_ticket
      result = []
      3.times do
        result << create_survey_result(ticket, 3)
      end
      get :show, controller_params(version: 'private', id: ticket.display_id, include: 'survey')
      assert_response 200
      match_json(ticket_show_pattern(ticket, result.last))
    end

    def test_show_without_survey_enabled
      ticket = create_ticket
      result = []
      3.times do
        result << create_survey_result(ticket, 3)
      end
      Account.any_instance.stubs(:features?).with(:default_survey).returns(false)
      Account.any_instance.stubs(:features?).with(:custom_survey).returns(false)
      get :show, controller_params(version: 'private', id: ticket.display_id, include: 'survey')
      assert_response 400
      match_json([bad_request_error_pattern('include', :require_feature, feature: 'Custom survey')])
      Account.any_instance.unstub(:features?)
    end

    def test_ticket_show_with_fone_call
      # while creating freshfone account during tests MixpanelWrapper was throwing error, so stubing that
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      ticket = new_ticket_from_call
      remove_wrap_params
      assert ticket.reload.freshfone_call.present?
      get :show, construct_params({ version: 'private', id: ticket.display_id }, false)
      assert_response 200
      match_json(ticket_show_pattern(ticket))
      MixpanelWrapper.unstub(:send_to_mixpanel)
    end

    def test_ticket_show_with_ticket_topic
      ticket = new_ticket_from_forum_topic
      remove_wrap_params
      get :show, construct_params({ version: 'private', id: ticket.display_id })
      assert_response 200
      match_json(ticket_show_pattern(ticket))
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
      match_json(create_ticket_pattern(params_hash, Helpdesk::Ticket.last))
      match_json(create_ticket_pattern({}, Helpdesk::Ticket.last))
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
      match_json(create_ticket_pattern(params_hash, Helpdesk::Ticket.last))
      match_json(create_ticket_pattern({}, Helpdesk::Ticket.last))
      assert Helpdesk::Ticket.last.attachments.size == (attachments.size + 1)
    end

    def test_create_with_invalid_cloud_files
      cloud_file_params = [{ filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 10000 }]
      params = ticket_params_hash.merge(cloud_files: cloud_file_params)
      post :create, construct_params({ version: 'private' }, params)
      assert_response 400
      match_json([bad_request_error_pattern(:application_id, :invalid_list, list: '10000')])
    end

    def test_create_with_cloud_files
      cloud_file_params = [{ filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 },
                           { filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 }]
      params_hash = ticket_params_hash.merge({cloud_files: cloud_file_params})
      post :create, construct_params({version: 'private'}, params_hash)
      assert_response 201
      match_json(create_ticket_pattern(params_hash, Helpdesk::Ticket.last))
      match_json(create_ticket_pattern({}, Helpdesk::Ticket.last))
      assert Helpdesk::Ticket.last.cloud_files.count == 2
    end

    def test_create_with_shared_attachments
      canned_response = create_response(
          title: Faker::Lorem.sentence,
          content_html: Faker::Lorem.paragraph,
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) })
      params_hash = ticket_params_hash.merge({attachment_ids: canned_response.shared_attachments.map(&:attachment_id)})
      post :create, construct_params({version: 'private'}, params_hash)
      assert_response 201
      match_json(create_ticket_pattern(params_hash, Helpdesk::Ticket.last))
      match_json(create_ticket_pattern({}, Helpdesk::Ticket.last))
      assert Helpdesk::Ticket.last.attachments.count == 1
    end

    def test_create_with_all_attachments
      #normal attachment
      file = fixture_file_upload('/files/attachment.txt', 'text/plain', :binary)
      # cloud file
      cloud_file_params = [{ filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 }]
      # shared attachment
      canned_response = create_response(
          title: Faker::Lorem.sentence,
          content_html: Faker::Lorem.paragraph,
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) })
      # draft attachment
      draft_attachment = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id)

      attachment_ids = canned_response.shared_attachments.map(&:attachment_id) | [draft_attachment.id]
      params_hash = ticket_params_hash.merge({attachment_ids: attachment_ids, attachments: [file], cloud_files: cloud_file_params})
      DataTypeValidator.any_instance.stubs(:valid_type?).returns(true)
      @request.env['CONTENT_TYPE'] = 'multipart/form-data' 
      post :create, construct_params({version: 'private'}, params_hash)
      DataTypeValidator.any_instance.unstub(:valid_type?)
      assert_response 201
      match_json(create_ticket_pattern(params_hash, Helpdesk::Ticket.last))
      match_json(create_ticket_pattern({}, Helpdesk::Ticket.last))
      assert Helpdesk::Ticket.last.attachments.count == 3
      assert Helpdesk::Ticket.last.cloud_files.count == 1
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
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
      ticket_field.update_attribute(:required_for_closure, true)
      ticket_ids = []
      rand(2..4).times do
        ticket_ids << create_ticket.id
      end
      properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5)
      params_hash = {ids: ticket_ids, properties: properties_hash}
      put :bulk_update, construct_params({ version: 'private' }, params_hash)
      failures = {}
      ticket_ids.each {|id| failures[id] = { ticket_field.label => [:datatype_mismatch, { code: :missing_field, expected_data_type: :String }]}}
      match_json(partial_success_response_pattern([], failures))
      assert_response 202
      ticket_field.update_attribute(:required_for_closure, false)
    end

    def test_bulk_update_success
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
      ticket_field.update_attribute(:required_for_closure, true)
      ticket_ids = []
      rand(2..4).times do
        ticket_ids << create_ticket.id
      end
      properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5, custom_fields: {ticket_field.label => 'Sample text'})
      params_hash = {ids: ticket_ids, properties: properties_hash}
      put :bulk_update, construct_params({ version: 'private' }, params_hash)
      match_json(partial_success_response_pattern(ticket_ids, {}))
      assert_response 202
      ticket_field.update_attribute(:required_for_closure, false)
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

    def test_update_properties_with_no_params
      ticket = create_ticket
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, {})
      assert_response 400
      match_json([bad_request_error_pattern('request', :fill_a_mandatory_field, field_names: 'due_by, agent, group, status')])
    end

    def test_update_properties
      ticket = create_ticket
      dt = 10.days.from_now.utc.iso8601
      agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      update_group = create_group_with_agents(@account, agent_list: [agent.id])
      tags = [Faker::Lorem.word, Faker::Lorem.word]
      params_hash = { due_by: dt, responder_id: agent.id, status: 2, priority: 4, group_id: update_group.id, tags: tags }
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      assert_response 204
      ticket.reload
      assert_equal dt, ticket.due_by.to_time.iso8601
      assert_equal agent.id, ticket.responder_id
      assert_equal 2, ticket.status
      assert_equal 4, ticket.priority
      assert_equal tags.count, ticket.tags.count
      assert_equal update_group.id, ticket.group_id
    end

    def test_update_properties_validation_for_closure_status
      ticket = create_ticket
      params_hash = { status: 4 }
      ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
      ticket_field.update_attribute(:required_for_closure, true)
      put :update_properties, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
      ticket_field.update_attribute(:required_for_closure, false)
      assert_response 400
      match_json([bad_request_error_pattern(ticket_field.label, :datatype_mismatch, expected_data_type: String)])
    end
  end
end
