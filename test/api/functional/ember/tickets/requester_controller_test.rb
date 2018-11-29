require_relative '../../../test_helper'
module Ember
  module Tickets
    class RequesterControllerTest < ActionController::TestCase
      include ApiTicketsTestHelper
      include ContactFieldsHelper
      include CompaniesTestHelper

      def setup
        super
        company = create_company
        @ticket = create_ticket(ticket_params_hash.merge(company_id: company.id))
        create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'Place', name: 'cf_place', field_options: { 'widget_position' => 7 }))
        create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'Position', name: 'cf_position', required_for_agent: 'true', editable_in_signup: 'true', field_options: { 'widget_position' => 8 }))
        Account.current.stubs(:enabled_features_list).returns([:requester_widget])
        @account.reload
      end

      def teardown
        super
        Account.current.unstub(:enabled_features_list)
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

      def wrap_cname(params)
        { requester: params }
      end

      def test_update_requester_check_feature
        Account.current.stubs(:enabled_features_list).returns([])
        params_hash = { contact: { name: Faker::Lorem.word, custom_fields: { position: Faker::Lorem.word } }, company: { custom_fields: { place: Faker::Lorem.word } } }
        put :update, construct_params({ version: 'private', id: @ticket.display_id }, params_hash)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Requester Widget'))
        Account.current.unstub(:enabled_features_list)
      end

      def test_update_requester_without_params
        params_hash = { contact: {}, company: {} }
        put :update, construct_params({ version: 'private', id: @ticket.display_id }, params_hash)
        assert_response 400
        match_json(request_error_pattern(:missing_params))
      end

      # Yet to figure out the proper error message for invalid fields, till then field name is used as it is now.
      def test_update_requester_with_invalid_field_params
        params_hash = { contact: { email: Faker::Internet.email, custom_fields: {} }, company: { domain: Faker::Lorem.word, custom_fields: {} } }
        put :update, construct_params({ version: 'private', id: @ticket.display_id }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(:domain, :invalid_field)])
      end

      def test_update_requester_with_invalid_datatype_params
        @account.reload
        params_hash = { contact: { name: Faker::Lorem.word, custom_fields: { position: 1 } }, company: { custom_fields: { place: Faker::Lorem.word } } }
        put :update, construct_params({ version: 'private', id: @ticket.display_id }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(:"contact.position", :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer)])
      end

      def test_update_requester_with_required_field_params
        @account.reload
        params_hash = { contact: { name: Faker::Lorem.word, custom_fields: { position: '' } }, company: { custom_fields: { place: Faker::Lorem.word } } }
        put :update, construct_params({ version: 'private', id: @ticket.display_id }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(:"contact.position", :blank)])
      end

      def test_update_requester_with_valid_params
        @account.reload
        params_hash = { contact: { name: Faker::Lorem.word, custom_fields: { position: Faker::Lorem.word } }, company: { custom_fields: { place: Faker::Lorem.word } } }
        put :update, construct_params({ version: 'private', id: @ticket.display_id }, params_hash)
        assert_response 200
        @ticket.reload
        assert_equal params_hash[:contact][:name], @ticket.requester.name
        assert_equal params_hash[:contact][:custom_fields][:position], @ticket.requester.custom_field['cf_position']
        assert_equal params_hash[:company][:custom_fields][:place], @ticket.company.custom_field['cf_place']
      end

      def test_update_requester_with_associated_company_name
        #ticket update with associtated company name
        @account.reload
        params_hash = { contact: { name: Faker::Lorem.word, custom_fields: { position: Faker::Lorem.word } }, company: { name: Faker::Lorem.word,   custom_fields: { place: Faker::Lorem.word } } }
        put :update, construct_params({ version: 'private', id: @ticket.display_id }, params_hash)
        assert_response 400
        match_json([bad_request_error_pattern(:name, :invalid_field)])
      end

      def test_update_requester_with_agent_as_requester
        agent = add_test_agent(@account)
        ticket = create_ticket(ticket_params_hash.merge(requester_id: agent.id))
        params_hash = { contact: { name: Faker::Lorem.word, custom_fields: { position: Faker::Lorem.word } }, company: { custom_fields: { place: Faker::Lorem.word } } }
        put :update, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
        assert_response 403
        match_json(request_error_pattern(:action_restricted,  action: :requester_update, reason: 'requester is agent'))
      end

      def test_update_requester_with_new_company
        #contact and ticket without company
        user  = add_new_user(@account)
        ticket = create_ticket(ticket_params_hash.merge(requester_id: user.id))
        params_hash = { contact: { name: Faker::Lorem.word, custom_fields: { position: Faker::Lorem.word } }, company: { name: Faker::Lorem.word,   custom_fields: { place: Faker::Lorem.word } } }
        put :update, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
        assert_response 200
        response = parse_response @response.body
        user.reload
        ticket.reload
        assert_equal user.customer_id, response['company']['id']
        assert_equal ticket.owner_id, response['company']['id']
      end

      def test_update_requester_with_new_company_2
        #ticket with deleted company
        company = create_company
        user  = add_new_user(@account, customer_id: company.id)
        ticket = create_ticket(ticket_params_hash.merge(requester_id: user.id))
        company.destroy
        @account.reload
        params_hash = { contact: { name: Faker::Lorem.word, custom_fields: { position: Faker::Lorem.word } }, company: { name: Faker::Lorem.word,   custom_fields: { place: Faker::Lorem.word } } }
        put :update, construct_params({ version: 'private', id: ticket.display_id }, params_hash)
        assert_response 200
        response = parse_response @response.body
        assert_equal params_hash[:contact][:name], response['contact']['name']
        assert_equal nil, response['company']
      end

      def test_update_requester_with_contact_only_and_company_required
        company_required_field = create_company_field(company_params(type: 'phone_number', field_type: 'custom_phone_number', label: 'Phone Number', name: 'phone_number', required_for_agent: true, field_options: { 'widget_position' => 4 }))
        @account.reload
        params_hash = { contact: { name: Faker::Lorem.word, custom_fields: { position: Faker::Lorem.word } }, company: {} }
        put :update, construct_params({ version: 'private', id: @ticket.display_id }, params_hash)
        assert_response 200
      ensure
        company_required_field.required_for_agent = false
        company_required_field.save
      end

      def test_update_requester_with_company_only_and_contact_required
        contact_required_field = create_contact_field(cf_params(type: 'phone_number', field_type: 'custom_phone_number', label: 'Custom Phone Number', name: 'phone_number', required_for_agent: true, field_options: { 'widget_position' => 9 }))
        @account.reload
        params_hash = { contact: {}, company: { custom_fields: { place: Faker::Lorem.word } } }
        put :update, construct_params({ version: 'private', id: @ticket.display_id }, params_hash)
        assert_response 200
      ensure
        contact_required_field.required_for_agent = false
        contact_required_field.save
      end
    end
  end
end
