require_relative '../../test_helper'
module Ember
  class ContactFieldsControllerTest < ActionController::TestCase
    include ContactFieldsTestHelper
    def wrap_cname(params)
      { contact_field: params }
    end

    def setup
      super
      initial_setup
    end

    @@initial_setup_run = false

    def initial_setup
      @private_api = true
      return if @@initial_setup_run
      @account.add_feature(:multiple_user_companies)
      @account.reload
      @@initial_setup_run = true
    end

    def test_contact_field_index
      get :index, controller_params(version: 'private')
      assert_response 200
      contact_fields = @account.contact_form.contact_fields
      pattern = contact_fields.map { |contact_field| private_contact_field_pattern(contact_field) }
      parsed_response = parse_response(response.body)
      parsed_response.each do |contact_field|
        contact_field.except!(*["created_at", "updated_at"])
      end
      match_custom_json(parsed_response.to_json, pattern.ordered!)
    end

    def test_index_without_privilege
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false).at_most_once
      get :index, controller_params(version: 'private')
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    ensure
      User.any_instance.unstub(:privilege?)
    end

    def test_index_ignores_pagination
      get :index, controller_params(version: 'private', per_page: 1, page: 2)
      assert_response 200
      assert JSON.parse(response.body).count > 1
    end
  end
end
