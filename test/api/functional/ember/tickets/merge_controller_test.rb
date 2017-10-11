require_relative '../../../test_helper'
['social_tickets_creation_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module Ember
  module Tickets
    class MergeControllerTest < ActionController::TestCase
      include TicketsTestHelper
      include CannedResponsesTestHelper
      include TicketsMergeTestHelper
      include SocialTicketsCreationHelper

      BULK_TICKET_CREATE_COUNT = 2

      def wrap_cname(params)
        { merge: params }
      end

      # tests for ticket merge
      # 1. should throw error for absence of primary_id, ticket_ids, note_in_primary, note_in_secondary params
      # 2. should throw error for invalid field in note_in_primary & note_secondary
      # 3. should throw error for invalid primary_id
      # 4. should throw error for invalid ticket_ids alone
      # 5. should throw partial error for a mix  of valid & invalid ticket_ids
      # 6. should throw error for primary ticket id without permission
      # 7. should throw error for secondary ticket_ids without permission
      # 8. should throw error if reply_cc limit exceeds
      # 9. should merge the tickets if all params are valid

      def test_merge_with_invalid_params
        put :merge, construct_params({ version: 'private' }, {})
        assert_response 400
        match_json(merge_attribute_missing_pattern)
      end

      def test_merge_with_invalid_field_in_notes
        primary_ticket = create_ticket
        source_tickets_ids = create_n_tickets(BULK_TICKET_CREATE_COUNT)
        request_params = sample_merge_request_params(primary_ticket.display_id, source_tickets_ids)
        request_params[:note_in_primary][:invalid_field] = Faker::Lorem.paragraph
        request_params[:note_in_secondary][:invalid_field] = Faker::Lorem.paragraph
        put :merge, construct_params({ version: 'private' }, request_params)
        assert_response 400
        match_json(merge_invalid_field_pattern)
      end

      def test_merge_with_invalid_primary_id
        source_tickets_ids = create_n_tickets(BULK_TICKET_CREATE_COUNT)
        request_params = sample_merge_request_params(source_tickets_ids.last + 1000, source_tickets_ids)
        put :merge, construct_params({ version: 'private' }, request_params)
        assert_response 404
      end

      def test_merge_with_invalid_ticket_ids
        primary_ticket = create_ticket
        invalid_ids = [primary_ticket.display_id + 100, primary_ticket.display_id + 200]
        request_params = sample_merge_request_params(primary_ticket.display_id, invalid_ids)
        put :merge, construct_params({ version: 'private' }, request_params)
        assert_response 400
        match_json(merge_invalid_ids_pattern(invalid_ids))
      end

      def test_merge_with_invalid_and_valid_ticket_ids
        primary_ticket = create_ticket
        source_tickets_ids = create_n_tickets(BULK_TICKET_CREATE_COUNT)
        invalid_ids = [primary_ticket.id + 100, primary_ticket.id + 200]
        request_params = sample_merge_request_params(primary_ticket.display_id, (invalid_ids + source_tickets_ids))
        put :merge, construct_params({ version: 'private' }, request_params)
        assert_response 400
        match_json(merge_invalid_ids_pattern(invalid_ids))
      end

      def test_merge_with_primary_ticket_without_permission
        primary_ticket = create_ticket
        source_tickets_ids = create_n_tickets(BULK_TICKET_CREATE_COUNT)
        user_stub_ticket_permission
        request_params = sample_merge_request_params(primary_ticket.display_id, source_tickets_ids)
        put :merge, construct_params({ version: 'private' }, request_params)
        assert_response 403
        user_unstub_ticket_permission
      end

      def test_merge_with_secondary_tickets_without_permission
        primary_ticket = create_ticket
        source_tickets_ids = create_n_tickets(BULK_TICKET_CREATE_COUNT)
        request_params = sample_merge_request_params(primary_ticket.display_id, source_tickets_ids)
        TicketMergeDelegator.any_instance.stubs(:ticket_permission?).returns(false)
        put :merge, construct_params({ version: 'private' }, request_params)
        assert_response 400
        TicketMergeDelegator.any_instance.unstub(:ticket_permission?)
        match_json(merge_imperssible_ids_pattern(source_tickets_ids))
      end

      def test_merge_with_invalid_and_permission_denined_tickets
        primary_ticket     = create_ticket
        invalid_ids        = [primary_ticket.id + 100, primary_ticket.id + 200]
        source_tickets_ids = create_n_tickets(BULK_TICKET_CREATE_COUNT)
        request_params = sample_merge_request_params(primary_ticket.display_id, source_tickets_ids + invalid_ids)
        TicketMergeDelegator.any_instance.stubs(:ticket_permission?).returns(false)
        put :merge, construct_params({ version: 'private' }, request_params)
        assert_response 400
        TicketMergeDelegator.any_instance.unstub(:ticket_permission?)
        match_json(merge_imperssible_invalid_pattern(source_tickets_ids, invalid_ids))
      end

      def test_merge_with_with_reply_cc_limit
        primary_ticket = create_ticket
        source_ticket = create_ticket 
        add_reply_cc_emails_to_ticket([source_ticket] + [primary_ticket], 30..35)
        request_params = sample_merge_request_params(primary_ticket.display_id, [source_ticket.display_id])
        request_params[:convert_recepients_to_cc] = true
        put :merge, construct_params({ version: 'private' }, request_params)
        assert_response 400
        match_json(merge_reply_cc_error_pattern)
      end

      def test_merge_incompletion
        primary_ticket = create_ticket
        source_tickets_ids = create_n_tickets(BULK_TICKET_CREATE_COUNT)
        request_params = sample_merge_request_params(primary_ticket.display_id, source_tickets_ids)
        TicketMerge.any_instance.stubs(:perform).returns(false)
        put :merge, construct_params({ version: 'private' }, request_params)
        TicketMerge.any_instance.unstub(:perform)
        assert_response 400
        match_json(merge_incompletion_pattern)
      end

      def test_merge_success
        primary_ticket = create_ticket
        source_tickets = 2.times.inject([]) { |arr, i| arr << create_ticket }
        add_reply_cc_emails_to_ticket(source_tickets + [primary_ticket], 2..5)
        add_timesheets_to_ticket(source_tickets)

        source_tickets.each do |ticket|
          assert @account.time_sheets.where(workable_type: 'Helpdesk::Ticket', workable_id: ticket.id).present?
        end
        refute @account.time_sheets.where(workable_type: 'Helpdesk::Ticket', workable_id: primary_ticket.id).present?

        request_params = sample_merge_request_params(primary_ticket.display_id, source_tickets.map(&:display_id))
        request_params[:convert_recepients_to_cc] = true
        put :merge, construct_params({ version: 'private' }, request_params)
        assert_response 204
        validate_merge_action(primary_ticket, source_tickets)
      end

      def test_merge_spammed_ticket
        primary_ticket = create_ticket(spam: true)
        source_tickets_ids = create_n_tickets(BULK_TICKET_CREATE_COUNT)
        request_params = sample_merge_request_params(primary_ticket.display_id, source_tickets_ids)
        put :merge, construct_params({ version: 'private' }, request_params)
        assert_response 404
      end

      def test_merge_twitter_and_email_ticket
        primary_twitter_ticket = create_twitter_ticket
        email_ticket = create_ticket(source: 1)
        request_params = sample_merge_request_params(primary_twitter_ticket.display_id, [email_ticket.display_id])
        put :merge, construct_params({ version: 'private' }, request_params)
        assert_response 204
        validate_merge_action(primary_twitter_ticket, [email_ticket], false)
      end

      def test_merge_assoc_tkt_as_primary_tkt
        enable_adv_ticketing([:parent_child_tickets]) { create_parent_child_tickets } #enabling feature to allow parent child tkt creation
        tracker_ticket   = create_tracker_ticket
        related_ticket   = create_related_tickets.first

        source_tickets_ids = create_n_tickets(BULK_TICKET_CREATE_COUNT)
        [tracker_ticket, related_ticket, @child_ticket, @parent_ticket].each do |assoc_ticket|
          request_params = sample_merge_request_params(assoc_ticket.display_id, source_tickets_ids)
          put :merge, construct_params({ version: 'private' }, request_params)
          assert_response 403
        end
      end

      def test_merge_assoc_tkt_as_secondary_tkt
        enable_adv_ticketing([:parent_child_tickets]) { create_parent_child_tickets }
        tracker_ticket = create_tracker_ticket
        related_ticket = create_related_tickets.first

        primary_ticket = create_ticket
        assoc_tkt_ids  = [tracker_ticket, related_ticket, @child_ticket, @parent_ticket].map(&:display_id)
        request_params = sample_merge_request_params(primary_ticket.display_id, assoc_tkt_ids)
        put :merge, construct_params({ version: 'private' }, request_params)
        assert_response 400
        match_json(merge_assoc_tkt_pattern(assoc_tkt_ids.sort))
      end

      def test_secondary_tkt_with_adv_features
        enable_adv_ticketing(%i(link_tickets parent_child_tickets)) do
          primary_tkt = create_ticket
          sec_tkt     = create_ticket
          request_params = sample_merge_request_params(primary_tkt.display_id, [sec_tkt.display_id])
          put :merge, construct_params({ version: 'private' }, request_params)
          assert_response 204
          assert_equal false, sec_tkt.reload.can_be_associated?
        end
      end

      def test_primary_tkt_with_adv_features
        enable_adv_ticketing(%i(link_tickets parent_child_tickets)) do
          primary_tkt = create_ticket
          sec_tkt     = create_ticket
          request_params = sample_merge_request_params(primary_tkt.display_id, [sec_tkt.display_id])
          put :merge, construct_params({ version: 'private' }, request_params)
          assert_response 204
          assert_equal true, primary_tkt.reload.can_be_associated?
        end
      end
    end
  end
end
