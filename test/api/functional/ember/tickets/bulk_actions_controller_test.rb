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
      include PrivilegesHelper
      include CannedResponsesTestHelper
      include AwsTestHelper

      CUSTOM_FIELDS = %w(number checkbox decimal text paragraph dropdown country state city date).freeze
      CUSTOM_FIELDS_CHOICES = Faker::Lorem.words(5).uniq.freeze

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
        ticket_ids = []
        rand(2..10).times do
          ticket_ids << create_ticket(ticket_params_hash).display_id
        end
        invalid_ids = [ticket_ids.last + 20, ticket_ids.last + 30]
        id_list = [*ticket_ids, *invalid_ids]
        post :bulk_execute_scenario, construct_params({ version: 'private' }, scenario_id: scenario_id, ids: id_list)
        failures = {}
        invalid_ids.each { |id| failures[id] = { id: :"is invalid" } }
        match_json(partial_success_response_pattern(ticket_ids, failures))
        assert_response 202
      end

      def test_bulk_execute_scenario_without_scenario_id
        scenario_id = create_scn_automation_rule(scenario_automation_params).id
        ticket_ids = []
        rand(2..10).times do
          ticket_ids << create_ticket(ticket_params_hash).display_id
        end
        post :bulk_execute_scenario, construct_params({ version: 'private' }, ids: ticket_ids)
        assert_response 400
        match_json([bad_request_error_pattern('scenario_id', :missing_field)])
      end

      def test_bulk_execute_scenario_with_invalid_scenario_id
        scenario_id = create_scn_automation_rule(scenario_automation_params).id
        ticket_ids = []
        rand(2..10).times do
          ticket_ids << create_ticket(ticket_params_hash).display_id
        end
        post :bulk_execute_scenario, construct_params({ version: 'private' }, scenario_id: scenario_id + 10, ids: ticket_ids)
        assert_response 400
        match_json([bad_request_error_pattern('scenario_id', :absent_in_db, resource: :scenario, attribute: :scenario_id)])
      end

      def test_bulk_execute_scenario_with_valid_ids
        scenario_id = create_scn_automation_rule(scenario_automation_params).id
        ticket_ids = []
        rand(2..10).times do
          ticket_ids << create_ticket(ticket_params_hash).display_id
        end
        post :bulk_execute_scenario, construct_params({ version: 'private' }, scenario_id: scenario_id, ids: ticket_ids)
        assert_response 202
      end

      def test_bulk_link_excess_number_of_tickets
        enable_adv_ticketing([:link_tickets]) do
          tracker_id = create_tracker_ticket.display_id
          ticket_ids = []
          (ApiConstants::MAX_ITEMS_FOR_BULK_ACTION + 1).times do
            ticket_ids << create_ticket.display_id
          end
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 400
          tickets = Helpdesk::Ticket.find_all_by_display_id(ticket_ids)
          tickets.each do |ticket|
            assert !ticket.related_ticket?
          end
        end
      end

      def test_bulk_link_non_existant_tickets_to_tracker
        enable_adv_ticketing([:link_tickets]) do
          tracker_id = create_tracker_ticket.display_id
          ticket_ids = []
          rand(3..5).times do
            ticket_ids << create_ticket.display_id
          end
          non_existant_tickets = []
          non_existant_tickets << Helpdesk::Ticket.last
          non_existant_ticket = non_existant_tickets.last
          non_existant_ticket.destroy
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 202
          assert !non_existant_ticket.related_ticket?
          tickets = Helpdesk::Ticket.find_all_by_display_id(ticket_ids)
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
          ticket_ids = []
          rand(3..5).times do
            ticket_ids << create_ticket.display_id
          end
          associated_tickets = Helpdesk::Ticket.find_all_by_display_id([ticket_ids[0], ticket_ids[1]])
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
          tickets = Helpdesk::Ticket.find_all_by_display_id(ticket_ids)
          valid_tickets = tickets - associated_tickets
          valid_tickets.each do |valid_ticket|
            assert valid_ticket.related_ticket?
          end
        end
      end

      def test_bulk_link_spammed_tickets
        enable_adv_ticketing([:link_tickets]) do
          tracker_id = create_tracker_ticket.display_id
          ticket_ids = []
          rand(3..5).times do
            ticket_ids << create_ticket.display_id
          end
          spammed_tickets = Helpdesk::Ticket.find_all_by_display_id([ticket_ids[0], ticket_ids[1]])
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
          tickets = Helpdesk::Ticket.find_all_by_display_id(ticket_ids)
          valid_tickets = tickets - spammed_tickets
          valid_tickets.each do |valid_ticket|
            assert valid_ticket.related_ticket?
          end
        end
      end

      def test_bulk_link_deleted_tickets
        enable_adv_ticketing([:link_tickets]) do
          tracker_id = create_tracker_ticket.display_id
          ticket_ids = []
          rand(3..5).times do
            ticket_ids << create_ticket.display_id
          end
          deleted_tickets = Helpdesk::Ticket.find_all_by_display_id([ticket_ids[0], ticket_ids[1]])
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
          tickets = Helpdesk::Ticket.find_all_by_display_id(ticket_ids)
          valid_tickets = tickets - deleted_tickets
          valid_tickets.each do |valid_ticket|
            assert valid_ticket.related_ticket?
          end
        end
      end

      def test_bulk_link_without_mandatory_field
        # Without tracker_id
        enable_adv_ticketing([:link_tickets]) do
          ticket_ids = []
          rand(2..4).times do
            ticket_ids << create_ticket.display_id
          end
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids }, false)
          end
          assert_response 400
          tickets = Helpdesk::Ticket.find_all_by_display_id(ticket_ids)
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
          tickets = Helpdesk::Ticket.find_all_by_display_id(ticket_ids)
          tickets.each do |ticket|
            assert !ticket.related_ticket?
          end
          user_unstub_ticket_permission
        end
      end

      def test_bulk_link_to_deleted_tracker
        test_bulk_link_for_tracker_with(deleted: true)
      end

      def test_bulk_link_for_tracker_with(attribute = { spam: true })
        enable_adv_ticketing([:link_tickets]) do
          tracker    = create_tracker_ticket
          tracker_id = tracker.display_id
          tracker.update_attributes(attribute)
          ticket_ids = []
          rand(2..4).times do
            ticket_ids << create_ticket.display_id
          end
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 400
          tickets = Helpdesk::Ticket.find_all_by_display_id(ticket_ids)
          tickets.each do |ticket|
            assert !ticket.related_ticket?
          end
        end
      end

      def test_bulk_link_to_deleted_tracker
        enable_adv_ticketing([:link_tickets]) do
          tracker    = create_tracker_ticket
          tracker_id = tracker.display_id
          tracker.update_attributes(deleted: true)
          ticket_ids = []
          rand(2..4).times do
            ticket_ids << create_ticket.display_id
          end
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 400
          tickets = Helpdesk::Ticket.find_all_by_display_id(ticket_ids)
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
          ticket_ids = []
          rand(2..4).times do
            ticket_ids << create_ticket.display_id
          end
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 400
          tickets = Helpdesk::Ticket.find_all_by_display_id(ticket_ids)
          tickets.each do |ticket|
            assert !ticket.related_ticket?
          end
        end
      end

      def test_bulk_link_to_invalid_tracker
        enable_adv_ticketing([:link_tickets]) do
          tracker_id = create_ticket.display_id
          ticket_ids = []
          rand(2..4).times do
            ticket_ids << create_ticket.display_id
          end
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 400
          tickets = Helpdesk::Ticket.find_all_by_display_id(ticket_ids)
          tickets.each do |ticket|
            assert !ticket.related_ticket?
          end
        end
      end

      def test_bulk_link_to_valid_tracker
        enable_adv_ticketing([:link_tickets]) do
          tracker_id = create_tracker_ticket.display_id
          ticket_ids = []
          rand(2..4).times do
            ticket_ids << create_ticket.display_id
          end
          Sidekiq::Testing.inline! do
            put :bulk_link, construct_params({ version: 'private', ids: ticket_ids, tracker_id: tracker_id }, false)
          end
          assert_response 204
          tickets = Helpdesk::Ticket.find_all_by_display_id(ticket_ids)
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
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        post :bulk_update, construct_params({ version: 'private' }, ids: ticket_ids)
        match_json([bad_request_error_pattern('request', :select_a_field)])
        assert_response 400
      end

      def test_bulk_update_with_incorrect_values
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        statuses = Helpdesk::TicketStatus.status_objects_from_cache(@account).map(&:status_id)
        incorrect_values = { priority: 90, status: statuses.last + 1, type: 'jksadjxyz' }
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.merge(incorrect_values) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        match_json([bad_request_error_pattern('priority', :not_included, list: '1,2,3,4'),
                    bad_request_error_pattern('status', :not_included, list: statuses.join(',')),
                    bad_request_error_pattern('type', :not_included, list: 'Question,Incident,Problem,Feature Request')])
        assert_response 400
      end

      def test_bulk_update_with_invalid_params
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.merge(responder_id: User.last.id + 10) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        match_json([bad_request_error_pattern('responder_id', :absent_in_db, resource: :agent, attribute: :responder_id)])
        assert_response 400
      end

      def test_bulk_update_with_invalid_ids
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        invalid_ids = [ticket_ids.last + 10, ticket_ids.last + 20]
        params_hash = { ids: [*ticket_ids, *invalid_ids], properties: update_ticket_params_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
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
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        failures = {}
        failures[parent_ticket.display_id] = { status: :unresolved_child }
        assert_response 202
        match_json(partial_success_response_pattern([], failures))
      end

      def test_bulk_update_closure_of_parent_ticket_success
        parent_ticket = create_ticket
        child_ticket = create_ticket(status: 4)
        Helpdesk::Ticket.any_instance.stubs(:child_ticket?).returns(true)
        Helpdesk::Ticket.any_instance.stubs(:associates).returns([child_ticket.display_id])
        Helpdesk::Ticket.any_instance.stubs(:association_type).returns(TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:assoc_parent])
        params_hash = { ids: [parent_ticket.display_id], properties: { status: 4 } }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern([parent_ticket.display_id], {}))
        parent_ticket.reload
        assert_equal 4, parent_ticket.status
      end

      def test_bulk_update_closure_status_without_notification
        ticket = create_ticket
        params_hash = { ids: [ticket.display_id], properties: { status: 5, skip_close_notification: true } }
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
          ticket_ids << create_ticket.display_id
        end
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5, custom_fields: { ticket_field.label => 'Sample text' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        match_json(partial_success_response_pattern(ticket_ids, {}))
        assert_response 202
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_reply_without_body
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
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
          ticket_ids << create_ticket.display_id
        end
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
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        add_privilege(User.current, :reply_ticket)
        User.unstub(:current)
      end

      def test_bulk_update_without_edit_privilege
        User.stubs(:current).returns(@agent)
        remove_privilege(User.current, :edit_ticket_properties)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
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

      def test_bulk_reply_with_attachments
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        attachment_id = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id).id
        canned_response = create_response(
          title: Faker::Lorem.sentence,
          content_html: Faker::Lorem.paragraph,
          visibility: ::Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          attachments: { resource: fixture_file_upload('files/attachment.txt', 'text/plain', :binary) }
        )
        cloud_file_params = [{ filename: 'image.jpg', url: CLOUD_FILE_IMAGE_URL, application_id: 20 }]
        reply_hash = { body: Faker::Lorem.paragraph,
                       attachment_ids: [attachment_id, canned_response.shared_attachments[0].attachment_id],
                       cloud_files: cloud_file_params }
        params_hash = {ids: ticket_ids, reply: reply_hash}
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

      def test_bulk_update_async
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_ids = []
        10.times do
          ticket_ids << create_ticket.display_id
        end
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
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(product_id: product.id).display_id
        end
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.merge(product_id: nil) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('product_id', :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: 'Null', prepend_msg: :input_received)])
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required: false)
      end

      def test_bulk_update_with_required_default_field_blank_in_db
        Helpdesk::TicketField.where(name: 'product').update_all(required: true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required: false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_default_field_blank
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: true)
        product = create_product
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(product_id: product.id).display_id
        end
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
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :group_id).merge(status: 5)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
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
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(status: 5, product_id: product.id).display_id
        end
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: true)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :status).merge(product_id: nil)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        failures = {}
        ticket_ids.each { |id| failures[id] = { 'product_id' => [:datatype_mismatch, { expected_data_type: 'Positive Integer', given_data_type: 'Null', prepend_msg: :input_received }] } }
        match_json(partial_success_response_pattern([], failures))
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_default_field_blank_in_db
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(status: 5).display_id
        end
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: true)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.except(:due_by, :fr_due_by, :status) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: false)
      end

      def test_bulk_update_with_required_custom_non_dropdown_field_blank
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
        ticket_field.update_attribute(:required, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(custom_field: { ticket_field.name => 'Sample Text' }).display_id
        end
        properties_hash = update_ticket_params_hash.merge(custom_fields: { ticket_field.label => '' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(ticket_field.label, :blank, code: :missing_field)])
      ensure
        ticket_field.update_attribute(:required, false)
      end

      def test_bulk_update_with_required_custom_non_dropdown_field_blank_in_db
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
        ticket_field.update_attribute(:required, true)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required, false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_custom_non_dropdown_field_blank
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5, custom_fields: { ticket_field.label => '' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(ticket_field.label, :blank, code: :missing_field)])
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_custom_non_dropdown_field_blank_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        failures = {}
        ticket_ids.each { |id| failures[id] = { ticket_field.label => [:datatype_mismatch, { expected_data_type: :String, given_data_type: 'Null', prepend_msg: :input_received }] } }
        match_json(partial_success_response_pattern([], failures))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_custom_non_dropdown_field_blank
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(status: 5, custom_field: { ticket_field.name => 'Sample Text' }).display_id
        end
        ticket_field.update_attribute(:required_for_closure, true)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :status).merge(custom_fields: { ticket_field.label => nil })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(ticket_field.label, :datatype_mismatch, expected_data_type: :String, given_data_type: 'Null', prepend_msg: :input_received)])
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_custom_non_dropdown_field_blank_in_db
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(status: 5).display_id
        end
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_text_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.except(:due_by, :fr_due_by, :status) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_with_required_custom_dropdown_field_blank
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(custom_field: { ticket_field.name => CUSTOM_FIELDS_CHOICES.sample }).display_id
        end
        properties_hash = update_ticket_params_hash.merge(custom_fields: { ticket_field.label => nil })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(ticket_field.label, :not_included, list: CUSTOM_FIELDS_CHOICES.join(','))])
      ensure
        ticket_field.update_attribute(:required, false)
      end

      def test_bulk_update_with_required_custom_dropdown_field_blank_in_db
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required, true)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required, false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_custom_dropdown_field_blank
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5, custom_fields: { ticket_field.label => nil })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(ticket_field.label, :not_included, list: CUSTOM_FIELDS_CHOICES.join(','))])
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_custom_dropdown_field_blank_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        failures = {}
        ticket_ids.each { |id| failures[id] = { ticket_field.label => [:not_included, list: CUSTOM_FIELDS_CHOICES.join(',')] } }
        match_json(partial_success_response_pattern([], failures))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_custom_dropdown_field_blank
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(status: 5, custom_field: { ticket_field.name => CUSTOM_FIELDS_CHOICES.sample }).display_id
        end
        ticket_field.update_attribute(:required_for_closure, true)
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :status).merge(custom_fields: { ticket_field.label => nil })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        failures = {}
        ticket_ids.each { |id| failures[id] = { ticket_field.label => [:not_included, list: CUSTOM_FIELDS_CHOICES.join(',')] } }
        match_json(partial_success_response_pattern([], failures))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_custom_dropdown_field_blank_in_db
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(status: 5).display_id
        end
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.except(:due_by, :fr_due_by, :status) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_with_required_default_field_with_incorrect_value
        Helpdesk::TicketField.where(name: 'product').update_all(required: true)
        product = create_product
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(product_id: product.id).display_id
        end
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.merge(product_id: product.id + 10) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('product_id', :absent_in_db, resource: :product, attribute: :product_id)])
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required: false)
      end

      def test_bulk_update_with_required_default_field_with_incorrect_value_in_db
        Helpdesk::TicketField.where(name: 'product').update_all(required: true)
        product = create_product
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(product_id: product.id + 10).display_id
        end
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required: false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_default_field_with_incorrect_value
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: true)
        product = create_product
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(product_id: product.id).display_id
        end
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
        product = create_product
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(product_id: product.id + 10, responder_id: @agent.id + 100).display_id
        end
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :responder_id).merge(status: 5)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
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
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(status: 5, product_id: product.id).display_id
        end
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
        product = create_product
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(status: 5, product_id: product.id + 10).display_id
        end
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.except(:due_by, :fr_due_by, :status) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: false)
      end

      def test_bulk_update_with_required_custom_non_dropdown_field_with_incorrect_value
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_number_#{@account.id}" }
        ticket_field.update_attribute(:required, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(custom_field: { ticket_field.name => 25 }).display_id
        end
        properties_hash = update_ticket_params_hash.merge(custom_fields: { ticket_field.label => 'Sample Text' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(ticket_field.label, :datatype_mismatch, expected_data_type: :Integer, given_data_type: 'String', prepend_msg: :input_received)])
      ensure
        ticket_field.update_attribute(:required, false)
      end

      def test_bulk_update_with_required_custom_non_dropdown_field_blank_with_incorrect_value_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_date_#{@account.id}" }
        ticket_field.update_attribute(:required, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(custom_field: { ticket_field.name => 'Sample Text' }).display_id
        end
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required, false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_custom_non_dropdown_field_with_incorrect_value
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_number_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5, custom_fields: { ticket_field.label => 'Sample Text' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(ticket_field.label, :datatype_mismatch, expected_data_type: :Integer, given_data_type: 'String', prepend_msg: :input_received)])
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_custom_non_dropdown_field_blank_with_incorrect_value_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_date_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(custom_field: { ticket_field.name => 'Sample Text' }).display_id
        end
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        failures = {}
        ticket_ids.each { |id| failures[id] = { ticket_field.label => [:invalid_date, { accepted: 'yyyy-mm-dd' }] } }
        match_json(partial_success_response_pattern([], failures))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_custom_non_dropdown_field_with_incorrect_value
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_number_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(status: 5, custom_field: { ticket_field.name => 25 }).display_id
        end
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :status).merge(custom_fields: { ticket_field.label => 'Sample Text' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(ticket_field.label, :datatype_mismatch, expected_data_type: :Integer, given_data_type: 'String', prepend_msg: :input_received)])
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_custom_non_dropdown_field_with_incorrect_value_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_date_#{@account.id}" }
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(status: 5, custom_field: { ticket_field.name => 'Sample Text' }).display_id
        end
        ticket_field.update_attribute(:required_for_closure, true)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.except(:due_by, :fr_due_by, :status) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_with_required_custom_dropdown_field_with_incorrect_value
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(custom_field: { ticket_field.name => CUSTOM_FIELDS_CHOICES.sample }).display_id
        end
        properties_hash = update_ticket_params_hash.merge(custom_fields: { ticket_field.label => 'invalid_choice' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(ticket_field.label, :not_included, list: CUSTOM_FIELDS_CHOICES.join(','))])
      ensure
        ticket_field.update_attribute(:required, false)
      end

      def test_bulk_update_with_required_custom_dropdown_field_blank_with_incorrect_value_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(custom_field: { ticket_field.name => 'invalid_choice' }).display_id
        end
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required, false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_custom_dropdown_field_with_incorrect_value
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5, custom_fields: { ticket_field.label => 'invalid_choice' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(ticket_field.label, :not_included, list: CUSTOM_FIELDS_CHOICES.join(','))])
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closure_status_with_required_for_closure_custom_dropdown_field_blank_with_incorrect_value_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(custom_field: { ticket_field.name => 'invalid_choice' }).display_id
        end
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by).merge(status: 5)
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        failures = {}
        ticket_ids.each { |id| failures[id] = { ticket_field.label => [:not_included, list: CUSTOM_FIELDS_CHOICES.join(',')] } }
        match_json(partial_success_response_pattern([], failures))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_custom_dropdown_field_with_incorrect_value
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(status: 5, custom_field: { ticket_field.name => CUSTOM_FIELDS_CHOICES.sample }).display_id
        end
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :status).merge(custom_fields: { ticket_field.label => 'invalid_choice' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(ticket_field.label, :not_included, list: CUSTOM_FIELDS_CHOICES.join(','))])
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_closed_tickets_with_required_for_closure_custom_dropdown_field_with_incorrect_value_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(status: 5, custom_field: { ticket_field.name => 'invalid_choice' }).display_id
        end
        ticket_field.update_attribute(:required_for_closure, true)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.except(:due_by, :fr_due_by, :status) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_with_non_required_default_field_blank
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: true)
        product = create_product
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(product_id: product.id).display_id
        end
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.merge(product_id: nil) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        Helpdesk::TicketField.where(name: 'product').update_all(required_for_closure: false)
      end

      def test_bulk_update_with_non_required_default_field_with_incorrect_value
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.merge(priority: 1000) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('priority', :not_included, list: ApiTicketConstants::PRIORITIES.join(','))])
      end

      def test_bulk_update_with_non_required_default_field_with_incorrect_value_in_db
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(type: 'Sample').display_id
        end
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.except(:priority) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

      def test_bulk_update_with_non_required_custom_non_dropdown_field_with_incorrect_value
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_number_#{@account.id}" }
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        properties_hash = update_ticket_params_hash.merge(custom_fields: { ticket_field.label => 'Sample Text' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(ticket_field.label, :datatype_mismatch, expected_data_type: :Integer, given_data_type: 'String', prepend_msg: :input_received)])
      end

      def test_bulk_update_with_non_required_custom_non_dropdown_field_with_incorrect_value_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_date_#{@account.id}" }
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(custom_field: { ticket_field.name => 'Sample Text' }).display_id
        end
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

      def test_bulk_update_with_non_required_default_field_with_invalid_value
        product = create_product
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(product_id: product.id).display_id
        end
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.merge(product_id: product.id + 10) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('product_id', :absent_in_db, resource: :product, attribute: :product_id)])
      end

      def test_bulk_update_with_non_required_default_field_with_invalid_value_in_db
        product = create_product
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(product_id: product.id + 10).display_id
        end
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

      def test_bulk_update_with_non_required_custom_dropdown_field_blank
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_field.update_attribute(:required_for_closure, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash.merge(custom_fields: { ticket_field.label => nil }) }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      ensure
        ticket_field.update_attribute(:required_for_closure, false)
      end

      def test_bulk_update_with_non_required_custom_dropdown_field_with_incorrect_value
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(custom_field: { ticket_field.name => CUSTOM_FIELDS_CHOICES.sample }).display_id
        end
        properties_hash = update_ticket_params_hash.merge(custom_fields: { ticket_field.label => 'invalid_choice' })
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(ticket_field.label, :not_included, list: CUSTOM_FIELDS_CHOICES.join(','))])
      end

      def test_bulk_update_with_non_required_custom_dropdown_field_with_incorrect_value_in_db
        ticket_field = @@ticket_fields.detect { |c| c.name == "test_custom_dropdown_#{@account.id}" }
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket(custom_field: { ticket_field.name => 'invalid_choice' }).display_id
        end
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        assert_response 202
        match_json(partial_success_response_pattern(ticket_ids, {}))
      end

      # There was a bug when we try to bulk update with type set without mandatory section fields
      def test_bulk_update_with_mandatory_dropdown_section_field
        sections = [
          {
            title: 'section1',
            value_mapping: ['Incident'],
            ticket_fields: ['dropdown']
          }
        ]
        create_section_fields(3, sections, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :type)
        properties_hash[:type] = 'Incident'
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        match_json(partial_success_response_pattern(ticket_ids, {}))
        assert_response 202
      ensure
        @account.section_fields.last.destroy
        @account.ticket_fields.find_by_name("test_custom_dropdown_#{@account.id}").update_attributes(required: false, field_options: { section: false })
      end

      def test_bulk_update_with_mandatory_section_fields
        sections = [
          {
            title: 'section1',
            value_mapping: ['Incident'],
            ticket_fields: ['test_custom_text']
          }
        ]
        create_section_fields(3, sections, true)
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
        properties_hash = update_ticket_params_hash.except(:due_by, :fr_due_by, :type)
        properties_hash[:type] = 'Incident'
        params_hash = { ids: ticket_ids, properties: properties_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        match_json(partial_success_response_pattern(ticket_ids, {}))
        assert_response 202
      ensure
        @account.section_fields.last.destroy
        @account.ticket_fields.find_by_name("test_custom_text_#{@account.id}").update_attributes(required: false, field_options: { section: false })
      end

      def test_bulk_update_with_invalid_custom_field
        ticket_ids = []
        rand(2..4).times do
          ticket_ids << create_ticket.display_id
        end
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
        tag = "#{Faker::Lorem.word}_#{Time.zone.now}"
        ticket = create_ticket
        ticket_ids = [ticket.display_id]
        ticket.tags.create(name: tag)
        params_hash = { ids: ticket_ids, properties: update_ticket_params_hash }
        post :bulk_update, construct_params({ version: 'private' }, params_hash)
        match_json(partial_success_response_pattern(ticket_ids, {}))
        assert ticket.tag_names.include? tag
        assert_response 202
      end
    end
  end
end
