require_relative '../test_helper'
class ApiContactFieldsControllerTest < ActionController::TestCase
  include Helpers::ContactFieldsTestHelper
  def wrap_cname(params)
    { api_contact_field: params }
  end

  # Contact Field Index
  def test_contact_field_index
    get :index, controller_params
    assert_response 200
    contact_fields = ContactField.scoped.order(:position)
    pattern = contact_fields.map { |contact_field| contact_field_pattern(contact_field) }
    match_json(pattern.ordered!)
  end

  def test_contact_field_index_with_all_custom_field_types
    create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'Area', editable_in_signup: 'true'))
    create_contact_field(cf_params(type: 'boolean', field_type: 'custom_checkbox', label: 'Metropolitian City', editable_in_signup: 'true'))
    create_contact_field(cf_params(type: 'date', field_type: 'custom_date', label: 'Joining date', editable_in_signup: 'true'))

    create_contact_field(cf_params(type: 'text', field_type: 'custom_dropdown', label: 'MCQ', editable_in_signup: 'true'))
    ContactFieldChoice.create(value: 'Choice 1', position: 1)
    ContactFieldChoice.create(value: 'Choice 2', position: 2)
    ContactFieldChoice.create(value: 'Choice 3', position: 3)
    ContactFieldChoice.update_all(account_id: @account.id)
    ContactFieldChoice.update_all(contact_field_id: ContactField.find_by_name('cf_mcq').id)

    get :index, controller_params
    assert_response 200
    contact_fields = ContactField.all
    pattern = contact_fields.map { |contact_field| contact_field_pattern(contact_field) }
    match_json(pattern)
  end

  def test_index_ignores_pagination
    get :index, controller_params(per_page: 1, page: 2)
    assert_response 200
    assert JSON.parse(response.body).count > 1
  end
end
