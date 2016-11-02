require_relative '../../../test_helper'
module Ember
  module Tickets
    class DraftsControllerTest < ActionController::TestCase
      include TicketsTestHelper

      def wrap_cname(params)
        { draft: params }
      end

      def test_save_draft_without_params
        ticket = create_ticket
        post :save_draft, construct_params({version: 'private', id: ticket.id}, {})
        assert_response 400
        match_json([bad_request_error_pattern('body', :datatype_mismatch, code: :missing_field, expected_data_type: :String)])
      end

      def test_save_draft_with_invalid_params
        ticket = create_ticket
        post :save_draft, construct_params({version: 'private', id: ticket.id}, { body: 'Sample text', cc_emails: 'ABC', bcc_emails: 'XYZ' })
        assert_response 400
        match_json([bad_request_error_pattern('cc_emails', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String),
                    bad_request_error_pattern('bcc_emails', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: String)])
      end

      def test_save_draft_with_invalid_from_email
        ticket = create_ticket
        params_hash = { body: 'Sample text', cc_emails: [Faker::Internet.email, Faker::Internet.email], bcc_emails: [Faker::Internet.email, Faker::Internet.email], from_email: Faker::Internet.email }
        post :save_draft, construct_params({version: 'private', id: ticket.id}, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern('from_email', :absent_in_db, resource: :"active email_config", attribute: :from_email)])
      end

      def test_save_draft
        ticket = create_ticket
        email_config = create_email_config
        params_hash = { body: 'Sample text', cc_emails: [Faker::Internet.email, Faker::Internet.email], bcc_emails: [Faker::Internet.email, Faker::Internet.email], from_email: email_config.reply_email }
        post :save_draft, construct_params({version: 'private', id: ticket.id}, params_hash)
        assert_response 204
      end

      def test_save_draft_with_attachments
        ticket = create_ticket
        email_config = create_email_config
        params_hash = { body: 'Sample text', cc_emails: [Faker::Internet.email], bcc_emails: [Faker::Internet.email], from_email: email_config.reply_email, attachment_ids: [1,2,3] }
        post :save_draft, construct_params({version: 'private', id: ticket.id}, params_hash)
        assert_response 204
      end

      def test_show_draft_without_save
        ticket = create_ticket
        get :show_draft, controller_params(version: 'private', id: ticket.id)
        assert_response 200
        match_json({})
      end

      def test_show_draft_after_save
        ticket = create_ticket
        unwrapped_params = { version: 'private', id: ticket.id }
        params_hash = { body: 'Sample text', cc_emails: [], from_email: nil }
        post :save_draft, construct_params(unwrapped_params, params_hash)
        assert_response 204
        get :show_draft, controller_params(unwrapped_params)
        assert_response 200
        match_json(reply_draft_pattern(params_hash))
      end

      def test_show_draft_after_save_with_all_params
        ticket = create_ticket
        email_config = create_email_config
        unwrapped_params = { version: 'private', id: ticket.id }
        params_hash = { body: 'Sample text', cc_emails: ["AB <#{Faker::Internet.email}>", Faker::Internet.email], 
                  bcc_emails: [Faker::Internet.email, "XYZ <#{Faker::Internet.email}>"], attachment_ids: [1,2,3],
                  from_email: "SUPPORT <#{email_config.reply_email}>" }
        post :save_draft, construct_params(unwrapped_params, params_hash)
        assert_response 204
        get :show_draft, controller_params(unwrapped_params)
        assert_response 200
        match_json(reply_draft_pattern(params_hash))
      end

      def test_stripping_invalid_emails
        ticket = create_ticket
        invalid_email = 'invalid'
        unwrapped_params = { version: 'private', id: ticket.id }
        params_hash = { body: 'Sample text', cc_emails: ["AB <#{Faker::Internet.email}>", Faker::Internet.email, invalid_email], 
                  bcc_emails: [Faker::Internet.email, "XYZ <#{Faker::Internet.email}>", invalid_email], attachment_ids: [1,2,3],
                  from_email: invalid_email }
        post :save_draft, construct_params(unwrapped_params, params_hash)
        assert_response 204
        get :show_draft, controller_params(unwrapped_params)
        assert_response 200
        [:cc_emails, :bcc_emails].each do |field|
          params_hash[field] = params_hash[field] - [invalid_email]
        end
        match_json(reply_draft_pattern(params_hash.except(:from_email)))
      end

      def test_clear_draft
        ticket = create_ticket
        unwrapped_params = { version: 'private', id: ticket.id }
        params_hash = { body: 'Sample text', cc_emails: [], from_email: nil }
        post :save_draft, construct_params(unwrapped_params, params_hash)
        assert_response 204
        delete :clear_draft, controller_params(unwrapped_params)
        assert_response 204
        get :show_draft, controller_params(unwrapped_params)
        assert_response 200
        match_json({})
      end
    end
  end
end
