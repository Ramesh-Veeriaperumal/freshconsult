require_relative '../test_helper'
class ApiContactFieldsControllerTest < ActionController::TestCase
  def wrap_cname(params)
    { api_contact_field: params }
  end

  def controller_params(params = {})
    remove_wrap_params
    request_params.merge(params)
  end

  # Contact Field Index
  def test_contact_field_index
    get :index, controller_params
    assert_response :success
    contact_fields = ContactField.all
    pattern = contact_fields.map { |contact_field| contact_field_pattern(contact_field) }
    match_json(pattern)
  end
end
