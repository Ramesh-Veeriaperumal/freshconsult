require_relative '../../../test_helper'
['canned_responses_helper.rb', 'group_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['account_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
module Ember
  module Tickets
    class BulkActionsControllerTest < ActionController::TestCase
      include ApiTicketsTestHelper
      include ScenarioAutomationsTestHelper
      include AttachmentsTestHelper
      include GroupHelper
      include CannedResponsesHelper
      include PrivilegesHelper
      include CannedResponsesTestHelper
      include AwsTestHelper
      include CustomFieldsTestHelper
      include AccountTestHelper

      CUSTOM_FIELDS             = %w(number checkbox decimal text paragraph dropdown country state city date).freeze
      BULK_CREATE_TICKET_COUNT  = 2

      def setup
        super
        Sidekiq::Worker.clear_all
        before_all
        SearchService::Client.any_instance.stubs(:write_count_object).returns(true)
        @account.add_feature(:scenario_automation)
      end

      def teardown
        SearchService::Client.any_instance.unstub(:write_count_object)
      end

      @@before_all_run = false

      def before_all
        @account.sections.map(&:destroy)
        return if @@before_all_run
        @account.features.forums.create
        @account.ticket_fields.custom_fields.each(&:destroy)
        Helpdesk::TicketStatus.find_by_status_id(2).update_column(:stop_sla_timer, false)
        @@ticket_fields = []
        @@custom_field_names = []
        @@ticket_fields << create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
        @@ticket_fields << create_custom_field_dropdown('test_custom_dropdown', CUSTOM_FIELDS_CHOICES)
        @@choices_custom_field_names = @@ticket_fields.map(&:name)
        CUSTOM_FIELDS.each do |custom_field|
          next if %w(dropdown country state city).include?(custom_field)
          @@ticket_fields << create_custom_field("test_custom_#{custom_field}", custom_field)
          @@custom_field_names << @@ticket_fields.last.name
        end
        create_skill if @account.skills.empty?
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
        tags = Faker::Lorem.words(3).uniq
        @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
        params_hash = { email: email, cc_emails: cc_emails, description: description, subject: subject,
                        priority: 2, status: 2, type: 'Problem', responder_id: @agent.id, source: 1, tags: tags,
                        due_by: 14.days.since.iso8601, fr_due_by: 1.day.since.iso8601, group_id: @create_group.id }
        params_hash
      end

      def update_ticket_params_hash
        agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        subject = Faker::Lorem.words(10).join(' ')
        description = Faker::Lorem.paragraph
        @update_group ||= create_group_with_agents(@account, agent_list: [agent.id])
        params_hash = { description: description, subject: subject, priority: 4, status: 7, type: 'Incident',
                        responder_id: agent.id, tags: %w(update_tag1 update_tag2),
                        due_by: 12.days.since.iso8601, fr_due_by: 4.days.since.iso8601, group_id: @update_group.id }
        params_hash
      end

      def test_bulk_execute_scenario_with_invalid_ticket_ids
        scenario_id = create_scn_automation_rule(scenario_automation_params).id
        ticket_ids = create_n_tickets(1, ticket_params_hash)
        invalid_ids = [ticket_ids.last + 20, ticket_ids.last + 30]
        id_list = [*ticket_ids, *invalid_ids]
        post :bulk_execute_scenario, construct_params({ version: 'private' }, scenario_id: scenario_id, ids: id_list)
        failures = {}
        invalid_ids.each { |id| failures[id] = { id: :"is invalid" } }
        match_json(partial_success_response_pattern(ticket_ids, failures))
        assert_response 202
      end
  
      def test_bulk_execute_scenario_to_respond_403
        scn_auto = @account.scn_automations.first || create_scn_automation_rule(scenario_automation_params)
        ticket_id = @account.tickets.first.try(:id) || create_n_tickets(1, ticket_params_hash).first
        @account.revoke_feature :scenario_automation
        @account.features.scenario_automations.destroy if @account.features.scenario_automations?
        post :bulk_execute_scenario, construct_params({ version: 'private' }, scenario_id: scn_auto.id, ids: [ticket_id])
        assert_response 403
      end
      
      def test_bulk_execute_scenario_with_invalid_ticket_types
        skip("ticket tests failing")
        @account.add_feature(:field_service_management)
        scenario_id = create_scn_automation_rule(scenario_automation_params).id
        param_hash = ticket_params_hash
        invalid_ids = create_n_tickets(2, param_hash)
        id_list = [*invalid_ids]
        Helpdesk::Ticket.any_instance.stubs(:service_task?).returns(true)
        post :bulk_execute_scenario, construct_params({ version: 'private' }, scenario_id: scenario_id, ids: id_list)
        failures = {}
        invalid_ids.each { |id| failures[id] = { id: :fsm_ticket_scenario_failure } }
        match_json(partial_success_response_pattern([], failures))
        assert_response 202
      ensure
        Helpdesk::Ticket.any_instance.unstub(:service_task?)
        @account.revoke_feature(:field_service_management)
      end

      def test_bulk_execute_scenario_without_scenario_id
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, ticket_params_hash)
        post :bulk_execute_scenario, construct_params({ version: 'private' }, ids: ticket_ids)
        assert_response 400
        match_json([bad_request_error_pattern('scenario_id', :missing_field)])
      end

      def test_bulk_execute_scenario_with_invalid_scenario_id
        scenario_id = @account.scn_automations.last.try(:id) || 1
        ticket_ids  = create_n_tickets(BULK_CREATE_TICKET_COUNT, ticket_params_hash)
        post :bulk_execute_scenario, construct_params({ version: 'private' }, scenario_id: scenario_id + 10, ids: ticket_ids)
        assert_response 400
        match_json([bad_request_error_pattern('scenario_id', :absent_in_db, resource: :scenario, attribute: :scenario_id)])
      end

      def test_bulk_execute_scenario_with_valid_ids
        scenario_id = create_scn_automation_rule(scenario_automation_params).id
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, ticket_params_hash)
        post :bulk_execute_scenario, construct_params({ version: 'private' }, scenario_id: scenario_id, ids: ticket_ids)
        assert_response 202
      end

      def test_bulk_execute_scenario_with_closure_action
        scenario_id = create_scn_automation_rule(scenario_automation_params.merge(close_action_params)).id
        Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: true)
        ticket_field1 = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
        ticket_field2 = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        [ticket_field1, ticket_field2].map { |x| x.update_attribute(:required_for_closure, true) }
        group = create_group(@account)
        invalid_tickets = []
        valid_tickets = []
        BULK_CREATE_TICKET_COUNT.times do
          invalid_tickets << create_ticket
          valid_tickets << create_ticket({custom_field: { ticket_field1.name => 'Sample Text', ticket_field2.name => CUSTOM_FIELDS_CHOICES.sample }}, group)
        end
        ticket_ids = (invalid_tickets | valid_tickets).map(&:display_id)
        Sidekiq::Testing.inline! do
          post :bulk_execute_scenario, construct_params({ version: 'private' }, scenario_id: scenario_id, ids: ticket_ids)
        end
        failures = {}
        invalid_tickets.each do |tkt|
          failures[tkt.display_id] = {
            'group_id' => [:datatype_mismatch, { expected_data_type: 'Positive Integer', given_data_type: 'Null', prepend_msg: :input_received }], 
            custom_field_error_label(ticket_field1.label) => [:datatype_mismatch, { expected_data_type: :String, given_data_type: 'Null', prepend_msg: :input_received }],
            custom_field_error_label(ticket_field2.label) => [:not_included, list: CUSTOM_FIELDS_CHOICES.join(',')]
          }
        end
        assert_response 202
        match_json(partial_success_response_pattern(valid_tickets.map(&:display_id), failures))
      ensure
        Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: false)
        [ticket_field1, ticket_field2].map { |x| x.update_attribute(:required_for_closure, false) }
      end

        def test_bulk_execute_scenario_with_closure_action_for_nested_dropdown_without_level2_value_present
        scenario_id = create_scn_automation_rule(scenario_automation_params.merge(close_action_params)).id
        ticket_field1 = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
        ticket_field2 = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
        [ticket_field1, ticket_field2].map { |x| x.update_attribute(:required_for_closure, true) }
        invalid_tickets = []
        BULK_CREATE_TICKET_COUNT.times do
          invalid_tickets << create_ticket({custom_field: { ticket_field1.name => 'Sample Text', ticket_field2.name => 'USA' }})
        end
        ticket_ids = (invalid_tickets).map(&:display_id)
        Sidekiq::Testing.inline! do
          post :bulk_execute_scenario, construct_params({ version: 'private' }, scenario_id: scenario_id, ids: ticket_ids)
        end
        assert_response 202
      ensure
        [ticket_field1, ticket_field2].map { |x| x.update_attribute(:required_for_closure, false) }
      end

      def test_bulk_execute_scenario_with_closure_of_parent_ticket_failure
        parent_ticket = create_ticket
        child_ticket = create_ticket
        Helpdesk::Ticket.any_instance.stubs(:child_ticket?).returns(true)
        Helpdesk::Ticket.any_instance.stubs(:associates).returns([child_ticket.display_id])
        Helpdesk::Ticket.any_instance.stubs(:association_type).returns(TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:assoc_parent])
        scenario_id = create_scn_automation_rule(scenario_automation_params.merge(close_action_params)).id
        post :bulk_execute_scenario, construct_params({ version: 'private' }, scenario_id: scenario_id, ids: [parent_ticket.display_id])
        failures = {}
        failures[parent_ticket.display_id] = { status: :unresolved_child }
        assert_response 202
        match_json(partial_success_response_pattern([], failures))
      ensure
        Helpdesk::Ticket.any_instance.unstub(:child_ticket?)
        Helpdesk::Ticket.any_instance.unstub(:associates)
        Helpdesk::Ticket.any_instance.unstub(:association_type)
      end

      def test_bulk_execute_scenario_with_closure_of_parent_ticket_success
        parent_ticket = create_ticket
        child_ticket = create_ticket(status: 5)
        Helpdesk::Ticket.any_instance.stubs(:child_ticket?).returns(true)
        Helpdesk::Ticket.any_instance.stubs(:associates).returns([child_ticket.display_id])
        Helpdesk::Ticket.any_instance.stubs(:association_type).returns(TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:assoc_parent])
        scenario_id = create_scn_automation_rule(scenario_automation_params.merge(close_action_params)).id
        post :bulk_execute_scenario, construct_params({ version: 'private' }, scenario_id: scenario_id, ids: [parent_ticket.display_id])
        assert_response 202
        match_json(partial_success_response_pattern([parent_ticket.display_id], {}))
      ensure
        Helpdesk::Ticket.any_instance.unstub(:child_ticket?)
        Helpdesk::Ticket.any_instance.unstub(:associates)
        Helpdesk::Ticket.any_instance.unstub(:association_type)
      end

      def test_bulk_link_excess_number_of_tickets
        enable_adv_ticketing([:link_tickets]) do
          tracker_id = create_tracker_ticket.display_id
          ticket_ids = create_n_tickets(ApiConstants::MAX_ITEMS_FOR_BULK_ACTION + 1)
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 400
          tickets = Helpdesk::Ticket.where(display_id: ticket_ids)
          tickets.each do |ticket|
            assert !ticket.related_ticket?
          end
        end
      end

      def test_bulk_link_non_existant_tickets_to_tracker
        enable_adv_ticketing([:link_tickets]) do
          tracker_id = create_tracker_ticket.display_id
          ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
          non_existant_tickets = []
          non_existant_tickets << Helpdesk::Ticket.last
          non_existant_ticket = non_existant_tickets.last
          non_existant_ticket.destroy
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 202
          assert !non_existant_ticket.related_ticket?
          tickets = Helpdesk::Ticket.where(display_id: ticket_ids)
          valid_tickets = tickets - non_existant_tickets
          valid_tickets.each do |valid_ticket|
            assert valid_ticket.related_ticket?
          end
        end
      end

      def test_bulk_link_associated_tickets_to_tracker
        enable_adv_ticketing([:link_tickets]) do
          tracker_id = create_tracker_ticket.display_id
          asso_tracker_id = create_tracker_ticket.display_id
          ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
          associated_tickets = Helpdesk::Ticket.where(display_id: [ticket_ids[0], ticket_ids[1]])
          associated_tickets.each do |associated_ticket|
            attributes = { association_type: 4, associates_rdb: asso_tracker_id }
            associated_ticket.update_attributes(attributes)
          end
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 202
          associated_tickets.each do |associated_ticket|
            associated_ticket.reload
            assert associated_ticket.associates_rdb != tracker_id
          end
          tickets = Helpdesk::Ticket.where(display_id: ticket_ids)
          valid_tickets = tickets - associated_tickets
          valid_tickets.each do |valid_ticket|
            assert valid_ticket.related_ticket?
          end
        end
      end

      def test_bulk_link_spammed_tickets
        enable_adv_ticketing([:link_tickets]) do
          tracker_id = create_tracker_ticket.display_id
          ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
          spammed_tickets = Helpdesk::Ticket.where(display_id: [ticket_ids[0], ticket_ids[1]])
          spammed_tickets.each do |spammed_ticket|
            spammed_ticket.update_attributes(spam: true)
          end
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 202
          spammed_tickets.each do |spammed_ticket|
            spammed_ticket.reload
            assert !spammed_ticket.related_ticket?
          end
          tickets = Helpdesk::Ticket.where(display_id: ticket_ids)
          valid_tickets = tickets - spammed_tickets
          valid_tickets.each do |valid_ticket|
            assert valid_ticket.related_ticket?
          end
        end
      end

      def test_bulk_link_deleted_tickets
        enable_adv_ticketing([:link_tickets]) do
          tracker_id = create_tracker_ticket.display_id
          ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
          deleted_tickets = Helpdesk::Ticket.where(display_id: [ticket_ids[0], ticket_ids[1]])
          deleted_tickets.each do |deleted_ticket|
            deleted_ticket.update_attributes(deleted: true)
          end
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 202
          deleted_tickets.each do |deleted_ticket|
            deleted_ticket.reload
            assert !deleted_ticket.related_ticket?
          end
          tickets = Helpdesk::Ticket.where(display_id: ticket_ids)
          valid_tickets = tickets - deleted_tickets
          valid_tickets.each do |valid_ticket|
            assert valid_ticket.related_ticket?
          end
        end
      end

      def test_bulk_link_without_mandatory_field
        # Without tracker_id
        enable_adv_ticketing([:link_tickets]) do
          ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids }, false)
          end
          assert_response 400
          tickets = Helpdesk::Ticket.where(display_id: ticket_ids)
          tickets.each do |ticket|
            assert !ticket.related_ticket?
          end
        end
      end

      def test_bulk_link_tickets_without_permission
        enable_adv_ticketing([:link_tickets]) do
          tracker_id = create_tracker_ticket.display_id
          ticket_ids = []
          ticket_ids << create_ticket.display_id
          user_stub_ticket_permission
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 202
          tickets = Helpdesk::Ticket.where(display_id: ticket_ids)
          tickets.each do |ticket|
            assert !ticket.related_ticket?
          end
          user_unstub_ticket_permission
        end
      end

      def test_bulk_link_to_deleted_tracker
        enable_adv_ticketing([:link_tickets]) do
          tracker    = create_tracker_ticket
          tracker_id = tracker.display_id
          tracker.update_attributes(deleted: true)
          ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 400
          tickets = Helpdesk::Ticket.where(display_id: ticket_ids)
          tickets.each do |ticket|
            assert !ticket.related_ticket?
          end
        end
      end

      def test_bulk_link_to_spammed_tracker
        enable_adv_ticketing([:link_tickets]) do
          tracker    = create_tracker_ticket
          tracker_id = tracker.display_id
          tracker.update_attributes(spam: true)
          ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 400
          tickets = Helpdesk::Ticket.where(display_id: ticket_ids)
          tickets.each do |ticket|
            assert !ticket.related_ticket?
          end
        end
      end

      def test_bulk_link_to_invalid_tracker
        enable_adv_ticketing([:link_tickets]) do
          tracker_id = create_ticket.display_id
          ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 400
          tickets = Helpdesk::Ticket.where(display_id: ticket_ids)
          tickets.each do |ticket|
            assert !ticket.related_ticket?
          end
        end
      end

      def test_bulk_link_to_valid_tracker
        enable_adv_ticketing([:link_tickets]) do
          tracker_id = create_tracker_ticket.display_id
          ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 204
          tickets = Helpdesk::Ticket.where(display_id: ticket_ids)
          tickets.each do |ticket|
            assert ticket.related_ticket?
          end
        end
      end

      def test_bulk_update_with_no_params
        post :bulk_update, construct_params({ version: 'private' }, {})
        match_json([bad_request_error_pattern('ids', :missing_field)])
        assert_response 400
      end

      def test_bulk_update_with_no_properties_or_reply
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        post :bulk_update, construct_params({ version: 'private' }, ids: ticket_ids)
        match_json([bad_request_error_pattern('request', :select_a_field)])
        assert_response 400
      end

      def test_bulk_update_with_incorrect_values
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        statuses = Helpdesk::TicketStatus.status_objects_from_cache(@account).map(&:status_id)
        incorrect_values = { priority: 90, status: statuses.last + 1, type: 'jksadjxyz' }
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.merge(incorrect_values) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)

        type_field_names = @account.ticket_fields.where(field_type: 'default_ticket_type').first.picklist_values.map(&:value).join(',')
        match_json([bad_request_error_pattern('priority', :not_included, list: '1,2,3,4'),
                    bad_request_error_pattern('status', :not_included, list: statuses.join(',')),
                    bad_request_error_pattern('type', :not_included, list: type_field_names)])
        assert_response 400
      end

      def test_bulk_update_with_invalid_params
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.merge(responder_id: User.last.id + 10) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        match_json([bad_request_error_pattern('responder_id', :absent_in_db, resource: :agent, attribute: :responder_id)])
        assert_response 400
      end

      def test_bulk_update_with_invalid_ids
        ticket_ids = create_n_tickets(1)
        invalid_ids = [ticket_ids.last + 10, ticket_ids.last + 20]
        params_hash = { ids: [*ticket_ids, *invalid_ids], properties: update_ticket_params_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        failures = {}
        invalid_ids.each { |id| failures[id] = { id: :"is invalid" } }
        match_json(partial_success_response_pattern(ticket_ids, failures))
        assert_response 202
      end

      def test_bulk_update_closure_of_parent_ticket_failure
        parent_ticket = create_ticket
        child_ticket = create_ticket
        Helpdesk::Ticket.any_instance.stubs(:child_ticket?).returns(true)
        Helpdesk::Ticket.any_instance.stubs(:associates).returns([child_ticket.display_id])
        Helpdesk::Ticket.any_instance.stubs(:association_type).returns(TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:assoc_parent])
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5)
        params_hash = { ids: [parent_ticket.display_id], properties: properties_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        failures = {}
        failures[parent_ticket.display_id] = { status: :unresolved_child }
        assert_response 202
        match_json(partial_success_response_pattern([], failures))
      end

      def test_bulk_update_closure_of_parent_ticket_success
        parent_ticket = create_ticket
        child_ticket = create_ticket(status: 4)
        Helpdesk::Ticket.any_instance.stubs(:child_ticket?).returns(true)
        Helpdesk::Ticket.any_instance.stubs(:associates_rdb).returns(parent_ticket.display_id)
        Helpdesk::Ticket.any_instance.stubs(:associates).returns([child_ticket.display_id])
        Helpdesk::Ticket.any_instance.stubs(:association_type).returns(TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:assoc_parent])
        params_hash = { ids: [parent_ticket.display_id], properties: { status: 4 } }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern([parent_ticket.display_id], {}))
        parent_ticket.reload
        assert_equal 4, parent_ticket.status
      end

      def test_bulk_update_closure_status_without_notification
        ticket = create_ticket
        params_hash = { ids: [ticket.display_id], properties: { status: 5, skip_close_notification: true } }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern([ticket.display_id], {}))
        ticket.reload
        assert_equal 5, ticket.status
      end

      def test_bulk_update_success
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5, custom_fields: { ticket_field.label => 'Sample text' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        match_json(partial_success_response_pattern(ticket_ids, {}))
        assert_response 202
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_fsm_tickets_with_required_for_closure_outside_section
        setup_field_service_management_feature do
          begin
            ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
            ticket_field.update_attribute(:required_for_closure, true)
            fsm_ticket = create_service_task_ticket
            assert_not_nil fsm_ticket
            properties_hash = { status: 5, skip_close_notification: false }
            params_hash = { ids: [fsm_ticket.id], properties: properties_hash }
            Sidekiq::Testing.inline! do
              post :bulk_update, construct_params({ version: 'private' }, params_hash)
            end
            assert_response 202
            match_json(partial_success_response_pattern([fsm_ticket.id], {}))
          ensure
            ticket_field.update_attribute(:required_for_closure, false)
            fsm_ticket.try(:destroy)
          end
        end
      end

      def test_bulk_reply_without_body
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        email_config = create_email_config
        reply_hash = { from_email: email_config.reply_email }
        params_hash = { ids: ticket_ids, reply: reply_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('body', :datatype_mismatch, code: :missing_field, expected_data_type: String)])
      end

      def test_bulk_update_with_reply
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        email_config = create_email_config
        reply_hash = { body: Faker::Lorem.paragraph, from_email: email_config.reply_email }
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash, reply: reply_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

      def test_bulk_update_without_reply_privilege
        User.stubs(:current).returns(@agent)
        remove_privilege(User.current, :reply_ticket)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        add_privilege(User.current, :reply_ticket)
        User.unstub(:current)
      end

      def test_bulk_update_without_edit_privilege
        User.stubs(:current).returns(@agent)
        remove_privilege(User.current, :edit_ticket_properties)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        email_config = create_email_config
        reply_hash = { body: Faker::Lorem.paragraph, from_email: email_config.reply_email }
        params_hash = { ids: ticket_ids, reply: reply_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        add_privilege(User.current, :edit_ticket_properties)
        User.unstub(:current)
      end

      def test_bulk_reply_for_bot_ticket
        Account.any_instance.stubs(:support_bot_configured?).returns(true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        ticket = @account.tickets.where(display_id: ticket_ids.first).first
        ticket.source = Helpdesk::Source::BOT
        ticket.save
        notes_count = ticket.notes.count
        reply_hash = { body: Faker::Lorem.paragraph }
        params_hash = { ids: ticket_ids, reply: reply_hash }
        stub_attachment_to_io do
          Sidekiq::Testing.inline! do
            post :bulk_update, construct_params({ version: 'private' }, params_hash)
          end
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
        ticket.reload
        assert_equal (notes_count + 1), ticket.notes.count
        Account.any_instance.unstub(:support_bot_configured?)
      end

      def test_bulk_reply_with_attachments
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
        canned_response = create_response(
          title: Faker::Lorem.sentence,
          content_html: Faker::Lorem.paragraph,
          visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) }
        )
        cloud_file_params = [{ name: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20 }]
        reply_hash = { body: Faker::Lorem.paragraph,
                       attachment_ids: [attachment_id, canned_response.shared_attachments[0].attachment_id],
                       cloud_files: cloud_file_params }
        params_hash = { ids: ticket_ids, reply: reply_hash }
        stub_attachment_to_io do
          Sidekiq::Testing.inline! do
            post :bulk_update, construct_params({ version: 'private' }, params_hash)
          end
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
        Helpdesk::Note.last(ticket_ids.size).each do |note|
          assert_equal 2, note.attachments.count
          assert_equal 1, note.cloud_files.count
        end
      end

      def test_bulk_reply_without_inline_attachments
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        email_config = create_email_config
        reply_hash = { from_email: email_config.reply_email, body: Faker::Lorem.paragraph }
        params_hash = { ids: ticket_ids, reply: reply_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

      def test_bulk_reply_with_invalid_inline_attachments
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        email_config = create_email_config
        reply_hash = {  from_email: email_config.reply_email, 
                        body: Faker::Lorem.paragraph,
                        inline_attachment_ids: [99999999] }
        params_hash = { ids: ticket_ids, reply: reply_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('inline_attachment_ids', :invalid_inline_attachments_list, invalid_ids: 99999999)])
      end

      def test_bulk_reply_with_valid_inline_attachment
        Helpdesk::Attachment.any_instance.stubs(:authenticated_s3_get_url).returns('spec/fixtures/files/attachment.txt')
        ticket_ids = create_n_tickets(5)
        email_config = create_email_config
        inline_attachment_id = create_attachment(attachable_type: 'Tickets Image Upload', attachable_id: @agent.id).id
        attachment = Helpdesk::Attachment.find_by_id(inline_attachment_id)
        inline_url = attachment.inline_url
        reply_hash = {  from_email: email_config.reply_email, 
                        body: Faker::Lorem.paragraph+"<img class=\"inline-image\" src=\""+attachment.inline_url+"\" data-id="+attachment.id.to_s+"></img>",
                        inline_attachment_ids: [inline_attachment_id] }
        params_hash = { ids: ticket_ids, reply: reply_hash }
        stub_attachment_to_io do
          Sidekiq::Testing.inline! do
            post :bulk_update, construct_params({ version: 'private' }, params_hash)
          end
        end
        Helpdesk::Attachment.any_instance.unstub(:authenticated_s3_get_url)
        assert_response 202
        Helpdesk::Note.last(ticket_ids.size).each do |note|
          data_id = "data-id="+attachment.id.to_s
          assert_equal note.body_html.include?(data_id),false
        end
      end

      def test_bulk_update_queued_jobs
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_ids = create_n_tickets(5)
        ::Tickets::BulkTicketActions.jobs.clear
        ::Tickets::BulkTicketReply.jobs.clear
        reply_hash = { body: Faker::Lorem.paragraph }
        properties_hash = update_ticket_params_hash.merge(custom_fields: { ticket_field.label => CUSTOM_FIELDS_CHOICES.sample })
        params_hash = { ids: ticket_ids, properties: properties_hash, reply: reply_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        match_json(partial_success_response_pattern(ticket_ids, {}))
        assert_response 202
        sidekiq_jobs = ::Tickets::BulkTicketActions.jobs | ::Tickets::BulkTicketReply.jobs
        assert_equal 2, sidekiq_jobs.size
        match_custom_json(sidekiq_jobs[0]['args'][0]['helpdesk_ticket'], bg_worker_update_pattern(properties_hash))
        assert sidekiq_jobs[1]['args'][0]['helpdesk_note'].present?
        assert sidekiq_jobs[0]['args'][0]['tags'].present?
        ::Tickets::BulkTicketActions.jobs.clear
        ::Tickets::BulkTicketReply.jobs.clear
      end

      def test_bulk_update_with_required_default_field_blank
        Helpdesk::TicketField.where(name: 'product').update_all(required: true)
        product = create_product
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, product_id: product.id)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.merge(product_id: nil) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('product_id', :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: 'Null', prepend_msg: :input_received)])
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required: false)
      end

      def test_bulk_update_with_required_default_field_blank_in_db
        Helpdesk::TicketField.where(name: 'product').update_all(required: true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required: false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_default_field_blank
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: true)
        product = create_product
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, product_id: product.id)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5, product_id: nil)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('product_id', :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: 'Null', prepend_msg: :input_received)])
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_default_field_blank_in_db
        Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: true)
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :group_id).merge(status: 5)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        failures = {}
        ticket_ids.each do |id|
          failures[id] = { 'group_id' => [:datatype_mismatch, { expected_data_type: 'Positive Integer', given_data_type: 'Null', prepend_msg: :input_received }],
                           'product_id' => [:datatype_mismatch, { expected_data_type: 'Positive Integer', given_data_type: 'Null', prepend_msg: :input_received }] }
        end
        match_json(partial_success_response_pattern([], failures))
      ensure
        Helpdesk::TicketField.where(name: 'group').update_all(required_for_closure: false)
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_default_field_blank
        product = create_product
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, status: 5, product_id: product.id)
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: true)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :status).merge(product_id: nil)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        failures = {}
        ticket_ids.each { |id| failures[id] = { 'product_id' => [:datatype_mismatch, { expected_data_type: 'Positive Integer', given_data_type: 'Null', prepend_msg: :input_received }] } }
        match_json(partial_success_response_pattern([], failures))
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_default_field_blank_in_db
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, status: 5)
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: true)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.except(:due_by, :fr_due_by, :status) }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: false)
      end

      def test_bulk_update_with_required_custom_non_dropdown_field_blank
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
        ticket_field.update_attribute(:required, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, custom_field: { ticket_field.name => 'Sample Text' })
        properties_hash = update_ticket_params_hash.merge(custom_fields: { ticket_field.label => '' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(custom_field_error_label(ticket_field.label), :blank, code: :missing_field)])
      ensure
        ticket_field.update_attribute(:required, false)
      end

      def test_bulk_update_with_required_custom_non_dropdown_field_blank_in_db
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
        ticket_field.update_attribute(:required, true)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required, false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_custom_non_dropdown_field_blank
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5, custom_fields: { ticket_field.label => '' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(custom_field_error_label(ticket_field.label), :blank, code: :missing_field)])
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_custom_non_dropdown_field_blank_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        failures = {}
        ticket_ids.each { |id| failures[id] = { custom_field_error_label(ticket_field.label) => [:datatype_mismatch, { expected_data_type: :String, given_data_type: 'Null', prepend_msg: :input_received }] } }
        match_json(partial_success_response_pattern([], failures))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_custom_non_dropdown_field_blank
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, status: 5, custom_field: { ticket_field.name => 'Sample Text' })
        ticket_field.update_attribute(:required_for_closure, true)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :status).merge(custom_fields: { ticket_field.label => nil })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(custom_field_error_label(ticket_field.label), :datatype_mismatch, expected_data_type: :String, given_data_type: 'Null', prepend_msg: :input_received)])
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_custom_non_dropdown_field_blank_in_db
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, status: 5)
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.except(:due_by, :fr_due_by, :status) }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_with_required_custom_dropdown_field_blank
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, custom_field: { ticket_field.name => CUSTOM_FIELDS_CHOICES.sample })
        properties_hash = update_ticket_params_hash.merge(custom_fields: { ticket_field.label => nil })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(custom_field_error_label(ticket_field.label), :not_included, list: CUSTOM_FIELDS_CHOICES.join(','))])
      ensure
        ticket_field.update_attribute(:required, false)
      end

      def test_bulk_update_with_required_custom_dropdown_field_blank_in_db
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required, true)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required, false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_custom_dropdown_field_blank
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5, custom_fields: { ticket_field.label => nil })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(custom_field_error_label(ticket_field.label), :not_included, list: CUSTOM_FIELDS_CHOICES.join(','))])
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_custom_nested_dropdown_field_blank
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5)
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_country_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_custom_dropdown_field_blank_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        failures = {}
        ticket_ids.each { |id| failures[id] = { custom_field_error_label(ticket_field.label) => [:not_included, list: CUSTOM_FIELDS_CHOICES.join(',')] } }
        match_json(partial_success_response_pattern([], failures))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_custom_dropdown_field_blank
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, status: 5, custom_field: { ticket_field.name => CUSTOM_FIELDS_CHOICES.sample })
        ticket_field.update_attribute(:required_for_closure, true)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :status).merge(custom_fields: { ticket_field.label => nil })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        failures = {}
        ticket_ids.each { |id| failures[id] = { custom_field_error_label(ticket_field.label) => [:not_included, list: CUSTOM_FIELDS_CHOICES.join(',')] } }
        match_json(partial_success_response_pattern([], failures))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_custom_dropdown_field_blank_in_db
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, status: 5)
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.except(:due_by, :fr_due_by, :status) }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_with_required_default_field_with_incorrect_value
        Helpdesk::TicketField.where(name: 'product').update_all(required: true)
        product = create_product
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, product_id: product.id)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.merge(product_id: product.id + 10) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('product_id', :absent_in_db, resource: :product, attribute: :product_id)])
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required: false)
      end

      def test_bulk_update_with_required_default_field_with_incorrect_value_in_db
        Helpdesk::TicketField.where(name: 'product').update_all(required: true)
        product_id = @account.products.last.try(:id) || 1
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, product_id: product_id + 10)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required: false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_default_field_with_incorrect_value
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: true)
        product = create_product
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, product_id: product.id)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5, product_id: product.id + 10)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('product_id', :absent_in_db, resource: :product, attribute: :product_id)])
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_default_field_with_incorrect_value_in_db
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: true)
        product_id = @account.reload.products.last.try(:id) || 1
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, product_id: product_id + 10_00, responder_id: @agent.id + 100)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :responder_id).merge(status: 5)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        failures = {}
        ticket_ids.each { |id| failures[id] = { 'product_id' => [:absent_in_db, { resource: :product, attribute: :product_id }] } }
        match_json(partial_success_response_pattern([], failures))
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_default_field_with_incorrect_value
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: true)
        product = create_product
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, status: 5, product_id: product.id)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :status).merge(product_id: product.id + 10)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('product_id', :absent_in_db, resource: :product, attribute: :product_id)])
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_default_field_with_incorrect_value_in_db
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: true)
        product_id = @account.products.last.try(:id) || 1
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, status: 5, product_id: product_id + 10)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.except(:due_by, :fr_due_by, :status) }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: false)
      end

      def test_bulk_update_with_required_custom_non_dropdown_field_with_incorrect_value
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_number_#{@account.id}" }
        ticket_field.update_attribute(:required, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, custom_field: { ticket_field.name => 25 })
        properties_hash = update_ticket_params_hash.merge(custom_fields: { ticket_field.label => 'Sample Text' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(custom_field_error_label(ticket_field.label), :datatype_mismatch, expected_data_type: :Integer, given_data_type: 'String', prepend_msg: :input_received)])
      ensure
        ticket_field.update_attribute(:required, false)
      end

      def test_bulk_update_with_required_custom_non_dropdown_field_blank_with_incorrect_value_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_date_#{@account.id}" }
        ticket_field.update_attribute(:required, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, custom_field: { ticket_field.name => 'Sample Text' })
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required, false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_custom_non_dropdown_field_with_incorrect_value
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_number_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5, custom_fields: { ticket_field.label => 'Sample Text' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(custom_field_error_label(ticket_field.label), :datatype_mismatch, expected_data_type: :Integer, given_data_type: 'String', prepend_msg: :input_received)])
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_custom_non_dropdown_field_blank_with_incorrect_value_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_date_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, custom_field: { ticket_field.name => 'Sample Text' })
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        failures = {}
        ticket_ids.each { |id| failures[id] = { ticket_field.label => [:invalid_date, { accepted: 'yyyy-mm-dd' }] } }
        match_json(partial_success_and_customfield_response_pattern([], failures))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_custom_non_dropdown_field_with_incorrect_value
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_number_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, status: 5, custom_field: { ticket_field.name => 25 })
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :status).merge(custom_fields: { ticket_field.label => 'Sample Text' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(custom_field_error_label(ticket_field.label), :datatype_mismatch, expected_data_type: :Integer, given_data_type: 'String', prepend_msg: :input_received)])
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_custom_non_dropdown_field_with_incorrect_value_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_date_#{@account.id}" }
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, status: 5, custom_field: { ticket_field.name => 'Sample Text' })
        ticket_field.update_attribute(:required_for_closure, true)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.except(:due_by, :fr_due_by, :status) }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_with_required_custom_dropdown_field_with_incorrect_value
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, custom_field: { ticket_field.name => CUSTOM_FIELDS_CHOICES.sample })
        properties_hash = update_ticket_params_hash.merge(custom_fields: { ticket_field.label => 'invalid_choice' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(custom_field_error_label(ticket_field.label), :not_included, list: CUSTOM_FIELDS_CHOICES.join(','))])
      ensure
        ticket_field.update_attribute(:required, false)
      end

      def test_bulk_update_with_required_custom_dropdown_field_blank_with_incorrect_value_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, custom_field: { ticket_field.name => 'invalid_choice' })
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required, false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_custom_dropdown_field_with_incorrect_value
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5, custom_fields: { ticket_field.label => 'invalid_choice' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(custom_field_error_label(ticket_field.label), :not_included, list: CUSTOM_FIELDS_CHOICES.join(','))])
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_custom_dropdown_field_blank_with_incorrect_value_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, custom_field: { ticket_field.name => 'invalid_choice' })
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        failures = {}
        ticket_ids.each { |id| failures[id] = { custom_field_error_label(ticket_field.label) => [:not_included, list: CUSTOM_FIELDS_CHOICES.join(',')] } }
        match_json(partial_success_response_pattern([], failures))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_custom_dropdown_field_with_incorrect_value
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, status: 5, custom_field: { ticket_field.name => CUSTOM_FIELDS_CHOICES.sample })
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :status).merge(custom_fields: { ticket_field.label => 'invalid_choice' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(custom_field_error_label(ticket_field.label), :not_included, list: CUSTOM_FIELDS_CHOICES.join(','))])
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_custom_dropdown_field_with_incorrect_value_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, status: 5, custom_field: { ticket_field.name => 'invalid_choice' })
        ticket_field.update_attribute(:required_for_closure, true)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.except(:due_by, :fr_due_by, :status) }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_with_non_required_default_field_blank
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: true)
        product = create_product
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, product_id: product.id)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.merge(product_id: nil) }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: false)
      end

      def test_bulk_update_with_non_required_default_field_with_incorrect_value
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.merge(priority: 1000) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('priority', :not_included, list: ApiTicketConstants::PRIORITIES.join(','))])
      end

      def test_bulk_update_with_non_required_default_field_with_incorrect_value_in_db
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, type: 'Sample')
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.except(:priority) }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

      def test_bulk_update_with_non_required_custom_non_dropdown_field_with_incorrect_value
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_number_#{@account.id}" }
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        properties_hash = update_ticket_params_hash.merge(custom_fields: { ticket_field.label => 'Sample Text' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(custom_field_error_label(ticket_field.label), :datatype_mismatch, expected_data_type: :Integer, given_data_type: 'String', prepend_msg: :input_received)])
      end

      def test_bulk_update_with_non_required_custom_non_dropdown_field_with_incorrect_value_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_date_#{@account.id}" }
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, custom_field: { ticket_field.name => 'Sample Text' })
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

      def test_bulk_update_with_non_required_default_field_with_invalid_value
        product = create_product
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, product_id: product.id)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.merge(product_id: product.id + 10) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('product_id', :absent_in_db, resource: :product, attribute: :product_id)])
      end

      def test_bulk_update_with_non_required_default_field_with_invalid_value_in_db
        product_id = @account.products.last.try(:id) || 1
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, product_id: product_id + 10)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

      def test_bulk_update_with_non_required_custom_dropdown_field_blank
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.merge(custom_fields: { ticket_field.label => nil }) }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_with_non_required_custom_dropdown_field_with_incorrect_value
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, custom_field: { ticket_field.name => CUSTOM_FIELDS_CHOICES.sample })
        properties_hash = update_ticket_params_hash.merge(custom_fields: { ticket_field.label => 'invalid_choice' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(custom_field_error_label(ticket_field.label), :not_included, list: CUSTOM_FIELDS_CHOICES.join(','))])
      end

      def test_bulk_update_with_non_required_custom_dropdown_field_with_incorrect_value_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT, custom_field: { ticket_field.name => 'invalid_choice' })
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

      # There was a bug when we try to bulk update with type set without mandatory section fields
      def test_bulk_update_with_mandatory_dropdown_section_field_for_default_type_field
        sections = [
          {
            title: 'section1',
            value_mapping: ['Incident'],
            ticket_fields: ['dropdown']
          }
        ]
        create_section_fields(3, sections, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :type)
        properties_hash[:type] = 'Incident'
        params_hash = { ids: ticket_ids, properties: properties_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        match_json(partial_success_response_pattern(ticket_ids, {}))
        assert_response 202
      ensure
        @account.section_fields.last.destroy
        @account.ticket_fields.find_by_name("test_custom_dropdown_#{@account.id}").update_attributes(required: false, field_options: { section: false })
      end

      def test_bulk_update_with_mandatory_section_fields_for_default_type_field
        sections = [
          {
            title: 'section1',
            value_mapping: ['Incident'],
            ticket_fields: ['test_custom_text']
          }
        ]
        create_section_fields(3, sections, true)
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :type)
        properties_hash[:type] = 'Incident'
        params_hash = { ids: ticket_ids, properties: properties_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        match_json(partial_success_response_pattern(ticket_ids, {}))
        assert_response 202
      ensure
        @account.section_fields.last.destroy
        @account.ticket_fields.find_by_name("test_custom_text_#{@account.id}").update_attributes(required: false, field_options: { section: false })
      end

      def test_bulk_update_closure_with_mandatory_section_field_for_non_required_custom_dropdown
        skip("ticket tests failing")
        dropdown_value = CUSTOM_FIELDS_CHOICES.sample
        sections = [
          {
            title: 'section1',
            value_mapping: [dropdown_value],
            ticket_fields: ['test_custom_text']
          }
        ]
        cust_dropdown_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        create_section_fields(cust_dropdown_field.id, sections, false, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket({custom_field: { cust_dropdown_field.name => dropdown_value }}).display_id
        end
        properties_hash = { status: 5 }
        params_hash = { ids: ticket_ids, properties: properties_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        section_field_id = cust_dropdown_field.dynamic_section_fields.first.ticket_field_id
        section_field = @account.ticket_fields.find_by_id(section_field_id)
        failures = {}
        ticket_ids.each do |tkt_id|
          failures[tkt_id] = {
            section_field.label => [:datatype_mismatch, { expected_data_type: :String, given_data_type: 'Null', prepend_msg: :input_received }]
          }
        end
        match_json(partial_success_and_customfield_response_pattern([], failures))
        assert_response 202
      ensure
        if @account.section_fields && @account.section_fields.last
          @account.section_fields.last.destroy
          section_field.update_attributes(required_for_closure: false, field_options: { section: false })
          cust_dropdown_field.update_attribute(:required_for_closure, false)
        end
      end

      def test_bulk_update_closure_with_mandatory_section_field_for_required_custom_dropdown
        skip("ticket tests failing")
        dropdown_value = CUSTOM_FIELDS_CHOICES.sample
        sections = [
          {
            title: 'section1',
            value_mapping: [dropdown_value],
            ticket_fields: ['test_custom_text']
          }
        ]
        cust_dropdown_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        cust_dropdown_field.update_attribute(:required_for_closure, true)
        create_section_fields(cust_dropdown_field.id, sections, false, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket({custom_field: { cust_dropdown_field.name => dropdown_value }}).display_id
        end
        properties_hash = { status: 5 }
        params_hash = { ids: ticket_ids, properties: properties_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        section_field_id = cust_dropdown_field.dynamic_section_fields.first.ticket_field_id
        section_field = @account.ticket_fields.find_by_id(section_field_id)
        failures = {}
        ticket_ids.each do |tkt_id|
          failures[tkt_id] = {
            section_field.label => [:datatype_mismatch, { expected_data_type: :String, given_data_type: 'Null', prepend_msg: :input_received }]
          }
        end
        match_json(partial_success_and_customfield_response_pattern([], failures))
        assert_response 202
      ensure
        if @account.section_fields && @account.section_fields.last
          @account.section_fields.last.destroy
          section_field.update_attributes(required_for_closure: false, field_options: { section: false })
          cust_dropdown_field.update_attribute(:required_for_closure, false)
        end
      end

      def test_bulk_update_with_invalid_custom_field
        ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :type)
        properties_hash[:custom_fields] = {
          'test_invalid_field' => 'invalid_value'
        }
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        match_json([bad_request_error_pattern('test_invalid_field', :invalid_field)])
        assert_response 400
      end

      def test_bulk_update_with_tags
        ticket = create_ticket
        ticket_ids = [ticket.display_id]
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        Sidekiq::Testing.inline! do
          post :bulk_update, construct_params({ version: 'private' }, params_hash)
        end
        match_json(partial_success_response_pattern(ticket_ids, {}))
        assert_response 202
      end

      def test_bulk_update_skill_id_without_feature
        Account.current.stubs(:skill_based_round_robin_enabled?).returns(false)
        user = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        login_as(user)
        group = create_group(@account, ticket_assign_type: 2)
        ticket = create_ticket({}, group)
        ticket_ids = [ticket.display_id]
        params_hash = { ids: ticket_ids, properties: { skill_id: 1 } }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        ticket.reload
        assert_equal nil, ticket.skill_id
        match_json([bad_request_error_pattern(:skill_id, :require_feature_for_attribute, code: :inaccessible_field, attribute: 'skill_id', feature: :skill_based_round_robin)])
        Account.current.unstub(:skill_based_round_robin_enabled?)
      end

      def test_bulk_update_skill_id_without_privilege
        Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
        user = add_test_agent(@account, role: Role.find_by_name('Agent').id)
        login_as(user)
        group = create_group(@account, ticket_assign_type: 2)
        ticket = create_ticket({}, group)
        ticket_ids = [ticket.display_id]
        params_hash = { ids: ticket_ids, properties: { skill_id: 1 } }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        ticket.reload
        assert_equal nil, ticket.skill_id
        match_json([bad_request_error_pattern(:skill_id, nil, code: :incompatible_field, append_msg: :no_edit_ticket_skill_privilege)])
        Account.current.unstub(:skill_based_round_robin_enabled?)
      end

       def test_bulk_update_skill_id_with_invalid_skill
        Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
        user = add_test_agent(@account, role: Role.find_by_name('Supervisor').id)
        login_as(user)
        group = create_group(@account, ticket_assign_type: 2)
        ticket = create_ticket({}, group)
        ticket_ids = [ticket.display_id]
        invalid_skill = @account.skills.length + 1
        params_hash = { ids: ticket_ids, properties: { skill_id: invalid_skill } }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        ticket.reload
        assert_equal nil, ticket.skill_id
        match_json([bad_request_error_pattern(:skill_id, nil, code: :invalid_value, append_msg: :invalid_skill_id)])
        Account.current.unstub(:skill_based_round_robin_enabled?)
      end

      def test_bulk_update_skill_id_with_privilege
        Account.current.stubs(:skill_based_round_robin_enabled?).returns(true)
        user = add_test_agent(@account, role: Role.find_by_name('Supervisor').id)
        login_as(user)
        group = create_group(@account, ticket_assign_type: 2)
        ticket = create_ticket({}, group)
        ticket_ids = [ticket.display_id]
        params_hash = { ids: ticket_ids, properties: { skill_id: 1 } }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        sidekiq_jobs = ::Tickets::BulkTicketActions.jobs
        assert_equal 1, sidekiq_jobs.size
        assert_equal 1, sidekiq_jobs.first["args"][0]["helpdesk_ticket"]["skill_id"]
        ::Tickets::BulkTicketActions.jobs.clear
        Account.current.unstub(:skill_based_round_robin_enabled?)
      end

      def test_bulk_unlink_related_ticket_from_tracker
        enable_adv_ticketing([:link_tickets]) do
          create_linked_tickets
          Sidekiq::Testing.inline! do
            put :bulk_unlink, construct_params({ version: 'private', ids: [@ticket_id] }, false)
          end
          assert_response 204
          ticket = Helpdesk::Ticket.find_by_display_id(@ticket_id)
          assert !ticket.related_ticket?
        end
      end

      def test_bulk_unlink_non_related_ticket
        enable_adv_ticketing([:link_tickets]) do
          ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
          associated_ticket = Helpdesk::Ticket.find_by_display_id(ticket_ids[0])
          associated_ticket.update_attributes(association_type: 1)
          Sidekiq::Testing.inline! do
            put :bulk_unlink, construct_params({ version: 'private', ids: ticket_ids }, false)
          end
          assert_response 202
          tickets = Helpdesk::Ticket.where(display_id: ticket_ids)
          assert tickets[0].parent_ticket?
          assert tickets[1].association_type.nil?
        end
      end

      def test_bulk_unlink_with_invalid_ids
        enable_adv_ticketing([:link_tickets]) do
          Sidekiq::Testing.inline! do
            put :bulk_unlink, construct_params({ version: 'private', ids: [123456789] }, false)
          end
          assert_response 202
        end
      end

      def test_bulk_unlink_without_mandatory_field
        enable_adv_ticketing([:link_tickets]) do
          asso_tracker_id = create_tracker_ticket.display_id
          ticket_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
          associated_tickets = Helpdesk::Ticket.where(display_id: [ticket_ids[0], ticket_ids[1]])
          associated_tickets.each do |associated_ticket|
            attributes = { association_type: 4, associates_rdb: asso_tracker_id }
            associated_ticket.update_attributes(attributes)
          end
          Sidekiq::Testing.inline! do
            put :bulk_unlink, construct_params({ version: 'private' }, false)
          end
          assert_response 400
          tickets = Helpdesk::Ticket.where(display_id: ticket_ids)
          tickets.each do |ticket|
            assert ticket.related_ticket?
          end
        end
      end

      def test_bulk_unlink_tickets_without_permission_for_tracker
        enable_adv_ticketing([:link_tickets]) do
          create_linked_tickets
          ::Tickets::UnlinkTickets.any_instance.stubs(:tracker_ticket_permission?).returns(false)
          Sidekiq::Testing.inline! do
            put :bulk_unlink, construct_params({ version: 'private', ids: [@ticket_id] }, false)
          end
          assert_response 204
          ticket = Helpdesk::Ticket.find_by_display_id(@ticket_id)
          assert ticket.related_ticket?
          ::Tickets::UnlinkTickets.any_instance.unstub(:tracker_ticket_permission?)
        end
      end

      def test_bulk_update_close_with_secure_text_field
        Account.any_instance.stubs(:secure_fields_enabled?).returns(true)
        ::Tickets::VaultDataCleanupWorker.jobs.clear
        ::Tickets::BulkTicketActions.jobs.clear
        name = "secure_text_#{Faker::Lorem.characters(rand(5..10))}"
        secure_text_field = create_custom_field_dn(name, 'secure_text')
        ticket_display_ids = create_n_tickets(BULK_CREATE_TICKET_COUNT)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5)
        params_hash = { ids: ticket_display_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        bulk_action_args = ::Tickets::BulkTicketActions.jobs.first['args'][0]
        ::Tickets::BulkTicketActions.new.perform(bulk_action_args)
        ticket_ids = Account.current.tickets.where(display_id: ticket_display_ids).pluck(:id)
        assert_equal 1, ::Tickets::VaultDataCleanupWorker.jobs.size
        vault_cleanup_args = ::Tickets::VaultDataCleanupWorker.jobs.first.deep_symbolize_keys[:args][0]
        assert_equal ticket_ids, vault_cleanup_args[:object_ids]
        assert_equal 'close', vault_cleanup_args[:action]
      ensure
        secure_text_field.destroy
        Account.reset_current_account
        ::Tickets::BulkTicketActions.jobs.clear
        ::Tickets::VaultDataCleanupWorker.jobs.clear
        Account.any_instance.unstub(:secure_fields_enabled?)
      end

      def test_bulk_execute_scenario_with_read_scope
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
        agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
        scn_automation_params = scenario_automation_params
        scn_automation_params[:accessible_attributes][:user_ids].push(agent.id)
        group1 = create_group_with_agents(@account, agent_list: [agent.id])
        group2 = create_group_with_agents(@account, agent_list: [agent.id])
        agent_group = agent.agent_groups.where(group_id: group1.id).first
        agent_group.write_access = false
        agent_group.save!
        ticket1 = create_ticket({}, group1)
        ticket2 = create_ticket({}, group2)
        ticket_ids = [ticket1.display_id, ticket2.display_id]
        login_as(agent)
        scenario_id = create_scn_automation_rule(scn_automation_params).id
        post :bulk_execute_scenario, construct_params({ version: 'private' }, scenario_id: scenario_id, ids: ticket_ids)
        assert_response 202
        failures = {}
        failure_ticket_ids = [ticket1.display_id]
        success_ticket_ids = [ticket2.display_id]
        failure_ticket_ids.each { |id| failures[id] = { id: :"is invalid" } }
        match_json(partial_success_response_pattern(success_ticket_ids, failures))
      ensure
        group1.destroy if group1.present?
        group2.destroy if group2.present?
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      end

      def test_bulk_link_to_valid_tracker_with_read_scope
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
        agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
        group1 = create_group_with_agents(@account, agent_list: [agent.id])
        group2 = create_group_with_agents(@account, agent_list: [agent.id])
        agent_group = agent.agent_groups.where(group_id: group1.id).first
        agent_group.write_access = false
        agent_group.save!
        enable_adv_ticketing([:link_tickets]) do
          tracker_id = create_tracker_ticket.display_id
          ticket1 = create_ticket({}, group1)
          ticket2 = create_ticket({}, group2)
          ticket_ids = [ticket1.display_id, ticket2.display_id]
          login_as(agent)
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 202
          failures = {}
          failure_ticket_ids = [ticket1.display_id]
          success_ticket_ids = [ticket2.display_id]
          failure_ticket_ids.each { |id| failures[id] = { id: :"is invalid" } }
          match_json(partial_success_response_pattern(success_ticket_ids, failures))
        end
      ensure
        group1.destroy if group1.present?
        group2.destroy if group2.present?
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      end

      def test_bulk_unlink_related_ticket_from_tracker_with_read_scope
        Account.any_instance.stubs(:advanced_ticket_scopes_enabled?).returns(true)
        agent = add_test_agent(@account, role: Role.where(name: 'Agent').first.id, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
        group1 = create_group_with_agents(@account, agent_list: [agent.id])
        agent_group = agent.agent_groups.where(group_id: group1.id).first
        agent_group.write_access = false
        agent_group.save!
        enable_adv_ticketing([:link_tickets]) do
          create_linked_tickets
          ticket = Helpdesk::Ticket.where(display_id: @ticket_id).first
          ticket.group_id = group1.id
          ticket.save!
          login_as(agent)
          Sidekiq::Testing.inline! do
            put :bulk_unlink, construct_params({ version: 'private', ids: [@ticket_id] }, false)
          end
          assert_response 204
          ticket = Helpdesk::Ticket.where(display_id: @ticket_id).first
          assert ticket.related_ticket?
        end
      ensure
        group1.destroy if group1.present?
        Account.any_instance.unstub(:advanced_ticket_scopes_enabled?)
      end

      private
        def partial_success_and_customfield_response_pattern(succeeded_ids, failures = {})
          {
            succeeded: succeeded_ids,
            failed: failures.map do |rec_id, errors|
              {
                id: rec_id,
                errors: errors.map do |field, value|
                  bad_request_error_pattern(custom_field_error_label(field), *value)
                end
              }
              end
          }
        end
    end
  end
end
