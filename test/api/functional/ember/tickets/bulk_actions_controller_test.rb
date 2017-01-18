require_relative '../../../test_helper'
['canned_responses_helper.rb', 'group_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module Ember
  module Tickets
    class BulkActionsControllerTest < ActionController::TestCase
      include TicketsTestHelper
      include ScenarioAutomationsTestHelper
      include AttachmentsTestHelper
      include GroupHelper
      include CannedResponsesHelper

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
        { bulk_action: params }
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

      def test_bulk_execute_scenario_with_invalid_ticket_ids
        scenario_id = create_scn_automation_rule(scenario_automation_params).id
        ticket_ids = []
        rand(2..10).times do
          ticket_ids << create_ticket(ticket_params_hash).display_id
        end
        invalid_ids = [ticket_ids.last + 20, ticket_ids.last + 30]
        id_list = [*ticket_ids, *invalid_ids]
        post :bulk_execute_scenario, construct_params({ version: 'private' }, { scenario_id: scenario_id, ids: id_list })
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
        post :bulk_execute_scenario, construct_params({ version: 'private' }, { ids: ticket_ids })
        assert_response 400
        match_json([bad_request_error_pattern('scenario_id', :missing_field)])
      end

      def test_bulk_execute_scenario_with_invalid_scenario_id
        scenario_id = create_scn_automation_rule(scenario_automation_params).id
        ticket_ids = []
        rand(2..10).times do
          ticket_ids << create_ticket(ticket_params_hash).display_id
        end
        post :bulk_execute_scenario, construct_params({ version: 'private' }, { scenario_id: scenario_id + 10, ids: ticket_ids })
        assert_response 400
        match_json([bad_request_error_pattern('scenario_id', :absent_in_db, resource: :scenario, attribute: :scenario_id)])
      end

      def test_bulk_execute_scenario_with_valid_ids
        scenario_id = create_scn_automation_rule(scenario_automation_params).id
        ticket_ids = []
        rand(2..10).times do
          ticket_ids << create_ticket(ticket_params_hash).display_id
        end
        post :bulk_execute_scenario, construct_params({ version: 'private' }, { scenario_id: scenario_id, ids: ticket_ids })
        assert_response 202
      end

      def test_bulk_update_with_no_params
        post :bulk_update, construct_params({ version: 'private' }, {})
        match_json([bad_request_error_pattern('ids', :missing_field)])
        assert_response 400
      end

      def test_bulk_update_with_no_properties_or_reply
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.id
        end
        post :bulk_update, construct_params({ version: 'private' }, { ids: ticket_ids })
        match_json([bad_request_error_pattern('request', :select_a_field)])
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
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
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
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
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
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
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
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        failures = {}
        ticket_ids.each {|id| failures[id] = { ticket_field.label => [:datatype_mismatch, { code: :missing_field, expected_data_type: :String }]}}
        match_json(partial_success_response_pattern([], failures))
        assert_response 202
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closure_of_parent_ticket_failure
        parent_ticket = create_ticket
        child_ticket = create_ticket
        Helpdesk::Ticket.any_instance.stubs(:child_ticket?).returns(true)
        Helpdesk::Ticket.any_instance.stubs(:associates).returns([child_ticket.display_id])
        Helpdesk::Ticket.any_instance.stubs(:association_type).returns(TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:assoc_parent])
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5)
        params_hash = {ids: [parent_ticket.display_id], properties: properties_hash}
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        failures = {}
        failures[parent_ticket.display_id] = { status: :unresolved_child}
        assert_response 202
        match_json(partial_success_response_pattern([], failures))
      end

      def test_bulk_update_closure_of_parent_ticket_success
        parent_ticket = create_ticket
        child_ticket = create_ticket(status: 4)
        Helpdesk::Ticket.any_instance.stubs(:child_ticket?).returns(true)
        Helpdesk::Ticket.any_instance.stubs(:associates).returns([child_ticket.display_id])
        Helpdesk::Ticket.any_instance.stubs(:association_type).returns(TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:assoc_parent])
        params_hash = {ids: [parent_ticket.display_id], properties: { status: 4 }}
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern([parent_ticket.display_id], {}))
        parent_ticket.reload
        assert_equal 4, parent_ticket.status
      end

      def test_bulk_update_closure_status_without_notification
        ticket = create_ticket
        params_hash = {ids: [ticket.display_id], properties: { status: 5, skip_close_notification: true }}
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern([ticket.display_id], {}))
        ticket.reload
        assert_equal 5, ticket.status
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
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        match_json(partial_success_response_pattern(ticket_ids, {}))
        assert_response 202
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_reply_without_body
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.id
        end
        email_config = create_email_config
        reply_hash = { from_email: email_config.reply_email }
        params_hash = { ids: ticket_ids, reply: reply_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('body', :datatype_mismatch, code: :missing_field, expected_data_type: String)])
      end

      def test_bulk_update_with_reply
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.id
        end
        email_config = create_email_config
        reply_hash = { body: Faker::Lorem.paragraph, from_email: email_config.reply_email }
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash, reply: reply_hash }
        Sidekiq::Testing.inline!
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

      def test_bulk_reply_with_attachments
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.id
        end
        attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
        canned_response = create_response(
            title: Faker::Lorem.sentence,
            content_html: Faker::Lorem.paragraph,
            visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
            attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) })
        cloud_file_params = [{ filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 },
                             { filename: "image.jpg", url: "https://www.dropbox.com/image.jpg", application_id: 20 }]
        reply_hash = { body: Faker::Lorem.paragraph, 
                       attachment_ids: [attachment_id, canned_response.shared_attachments[0].attachment_id], 
                       cloud_files: cloud_file_params }
        params_hash = {ids: ticket_ids, reply: reply_hash}
        Sidekiq::Testing.inline!
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
        Helpdesk::Note.last(ticket_ids.size).each do |note|
          assert_equal 2, note.attachments.count
          assert_equal 2, note.cloud_files.count
        end
      end

      def test_bulk_update_async
        ticket_ids = []
        10.times do
          ticket_ids << create_ticket.id
        end
        Sidekiq::Testing.inline!
        reply_hash = { body: Faker::Lorem.paragraph }
        params_hash = {ids: ticket_ids, properties: update_ticket_params_hash, reply: reply_hash}
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        match_json(partial_success_response_pattern(ticket_ids, {}))
        assert_response 202
      end
    end
  end
end