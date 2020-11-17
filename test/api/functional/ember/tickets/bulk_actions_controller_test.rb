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
        p "response.body :: #{response.body.inspect}" if response.status != 202
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
    end
  end
end
