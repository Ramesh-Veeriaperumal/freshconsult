require_relative '../../test_helper'
module Ember
  class CompanyFieldsControllerTest < ActionController::TestCase
    include CompaniesTestHelper
    def wrap_cname(params)
      { company_field: params }
    end

    def setup
      super
      @private_api = true
    end

    def test_index_without_privilege
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false).at_most_once
      get :index, controller_params(version: 'private')
      assert_response 403
      match_json(request_error_pattern(:access_denied))
    ensure
      User.any_instance.unstub(:privilege?)
    end

    def test_index
      get :index, controller_params(version: 'private')
      pattern = []
      Account.current.company_form.company_fields.each do |cf|
        pattern << private_company_field_pattern(CompanyField.find(cf.id))
      end
      assert_response 200
      parsed_response = parse_response(response.body)
      parsed_response.each do |company_field|
        company_field.except!(*["created_at", "updated_at"])
      end
      match_custom_json(parsed_response.to_json, pattern.ordered!)
    end

    def test_index_ignores_pagination
      get :index, controller_params(version: 'private', per_page: 1, page: 2)
      assert_response 200
      assert JSON.parse(response.body).count > 1
    end
  end
end
