require_relative '../../test_helper.rb'
# Tests written for api endpoints of api/ticket_fields controller.
class Admin::TicketFieldsControllerTest < ActionController::TestCase
  def wrap_cname(params)
    params
  end

  # test_helper
  def common_field_params(input_params = {})
    params_hash = {
      label_for_customers: input_params[:label_for_customers] || Faker::Lorem.characters(10),
      label: input_params[:label] || Faker::Lorem.characters(10),
      type: input_params[:type] || 'custom_text'
    }
    params_hash.merge(input_params.except(*params_hash.keys))
  end

  def custom_dropdown_params(input_params = {})
    input_params[:type] = 'custom_dropdown'
    common_field_params(input_params)
  end

  def nested_field_params(input_params = {})
    first_nested_ticket_field = input_params.try(:[], :nested_ticket_fields).try(:[], 0) || {}
    second_nested_ticket_field = input_params.try(:[], :nested_ticket_fields).try(:[], 1) || {}
    params = {
      type: 'nested_field',
      nested_ticket_fields: [
        {
          label: first_nested_ticket_field[:label] || Faker::Lorem.characters(10),
          label_in_portal: first_nested_ticket_field[:label_in_portal] || Faker::Lorem.characters(10)
        },
        {
          label: second_nested_ticket_field[:label] || Faker::Lorem.characters(10),
          label_in_portal: second_nested_ticket_field[:label_in_portal] || Faker::Lorem.characters(10)
        }
      ]
    }
    common_field_params(input_params.merge(params))
  end

  def nested_field_response_pattern(expected_output, ticket_field)
    response_pattern = ticket_field_pattern(expected_output, ticket_field)
    response_pattern['nested_ticket_fields'] = []
    ticket_field.nested_ticket_fields.each do |nested_field|
      response_pattern['nested_ticket_fields'] = response_pattern['nested_ticket_fields'].push("label": nested_field.label,
                                                                                               "label_in_portal": nested_field.label_in_portal,
                                                                                               "description": nested_field.description,
                                                                                               "name": TicketDecorator.display_name(expected_output[:name] || nested_field.name),
                                                                                               "level": nested_field.level,
                                                                                               "ticket_field_id": nested_field.ticket_field_id,
                                                                                               "created_at": ticket_field.utc_format(expected_output[:created_at] || ticket_field.created_at),
                                                                                               "updated_at": ticket_field.utc_format(expected_output[:updated_at] || ticket_field.updated_at))
    end
    response_pattern[:choices] = Array
    response_pattern
  end

  def custom_dropdown_field_pattern(expected_output, ticket_field)
    ticket_field_pattern(expected_output, ticket_field).merge(choices: Array)
  end

  def ticket_field_pattern(expected_output, ticket_field)
    {
      id: expected_output[:id] || ticket_field.id,
      label: expected_output[:labe] || ticket_field.label,
      description: expected_output[:description] || ticket_field.description,
      position: expected_output[:position] || ticket_field.position,
      default: expected_output[:default] || ticket_field.default,
      required_for_closure: expected_output[:required_for_closure] || ticket_field.required_for_closure,
      created_at: ticket_field.utc_format(expected_output[:created_at] || ticket_field.created_at),
      updated_at: ticket_field.utc_format(expected_output[:updated_at] || ticket_field.updated_at),
      name: TicketDecorator.display_name(expected_output[:name] || ticket_field.name),
      label_for_customers: expected_output[:label_for_customers] || ticket_field.label_in_portal,
      type: expected_output[:type] || ticket_field.field_type,
      required_for_agents: expected_output[:required_for_agents] || ticket_field.required,
      required_for_customers: expected_output[:required_for_customers] || ticket_field.required_in_portal,
      displayed_to_customers: expected_output[:displayed_to_customers] || ticket_field.visible_in_portal,
      customers_can_edit: expected_output[:customers_can_edit] || ticket_field.editable_in_portal
    }
  end

  def test_create_with_wrong_privilege
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    post :create, construct_params({}, common_field_params)
    assert_response 403
  end

  def test_create_with_wrong_data_types_for_text_related_fields
    params = { label: 1, label_for_customers: 1, description: 1 }
    post :create, construct_params({}, common_field_params(params))
    result = parse_response response.body
    match_json([
                 bad_request_error_pattern('label', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                 bad_request_error_pattern('label_for_customers', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer),
                 bad_request_error_pattern('description', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer)
               ])
  end

  def test_create_with_max_length_for_text_related_fields
    params = {
      label: "A#{Faker::Lorem.characters(255)}",
      label_for_customers: "A#{Faker::Lorem.characters(255)}",
      type: "A#{Faker::Lorem.characters(255)}",
      description: "A#{Faker::Lorem.characters(255)}"
    }
    post :create, construct_params({}, common_field_params(params))
    assert_response 400
  end

  def test_create_with_wrong_accepted_type
    params = { type: 'test_type' }
    post :create, construct_params({}, common_field_params(params))
    assert_response 400
    match_json([bad_request_error_pattern('type', :not_included,
                                          list: Helpdesk::TicketField::MODIFIABLE_CUSTOM_FIELD_TYPES.uniq.join(','))])
  end

  def test_create_file_type_field
    params = { type: 'custom_file' }
    post :create, construct_params({}, common_field_params(params))
    assert_response 400
    match_json([bad_request_error_pattern('type', :not_included,
                                          list: Helpdesk::TicketField::MODIFIABLE_CUSTOM_FIELD_TYPES.uniq.join(','))])
  end

  def test_create_with_wrong_boolean_params
    params = {
      required_for_closure: '',
      required_for_agents: '',
      required_for_customers: '',
      customers_can_edit: '',
      displayed_to_customers: ''
    }
    post :create, construct_params({}, common_field_params(params))
    assert_response 400
    match_json([
                 bad_request_error_pattern('required_for_closure', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String, code: :invalid_value),
                 bad_request_error_pattern('required_for_agents', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String, code: :invalid_value),
                 bad_request_error_pattern('required_for_customers', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String, code: :invalid_value),
                 bad_request_error_pattern('customers_can_edit', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String, code: :invalid_value),
                 bad_request_error_pattern('displayed_to_customers', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String, code: :invalid_value)
               ])
  end

  def test_create_with_wrong_position_number
    params = { position: -1 }
    post :create, construct_params({}, common_field_params(params))
    assert_response 400
    match_json([bad_request_error_pattern('position', :datatype_mismatch, expected_data_type: 'Positive Integer', code: :invalid_value)])
  end

  # Custom DropDown related tests starts here.
  def test_create_with_duplicate_choices_in_under_ticket_field
    choice_value = "A#{Faker::Lorem.characters(10)}"
    params = {
      choices: [{ value: choice_value, choices: [] }, { value: choice_value, choices: [] }]
    }
    post :create, construct_params({}, common_field_params(params))
    assert_response 400
    # result = parse_response response.body
  end

  def test_create_with_choices_of_in_correct_data_type
    params = {
      choices: [{ value: 1, choices: [] }]
    }
    post :create, construct_params({}, common_field_params(params))
    assert_response 400
    # result = parse_response response.body
  end

  # Nested Field related tests starts here.
  def test_create_with_duplicate_choices_in_under_same_parent
    choice_value = "A#{Faker::Lorem.characters(10)}"
    params = {
      choices: [{ value: choice_value, choices: [] }, { value: choice_value, choices: [] }]
    }
    post :create, construct_params({}, nested_field_params(params))
    assert_response 409
    # result = parse_response response.body
  end

  # test for delegator.
  def test_create_of_ticket_field_with_duplicate_label
    params = { label: "A#{Faker::Lorem.characters(10)}" }
    post :create, construct_params({}, common_field_params(params))
    post :create, construct_params({}, common_field_params(params))
    assert_response 409
  end

  # test cases for positive/ticket field creation
  def test_success_create_of_nested_field
    params = {
      choices: [{ value: "A#{Faker::Lorem.characters(10)}", choices: [{ value: "A#{Faker::Lorem.characters(10)}", choices: [] }] }, { value: "A#{Faker::Lorem.characters(10)}", choices: [] }]
    }
    params = construct_params({}, nested_field_params(params))
    ticket_field_id = @account.ticket_fields_with_nested_fields.last.id
    post :create, params
    assert_response 201
    ticket_field = @account.ticket_fields_with_nested_fields.find(ticket_field_id + 1)
    match_json(nested_field_response_pattern({}, ticket_field))
  end

  def test_success_create_of_custom_dropdown_field
    params = { choices: [{ value: "A#{Faker::Lorem.characters(10)}" }, { value: "A#{Faker::Lorem.characters(10)}" }] }
    post :create, construct_params({}, custom_dropdown_params(params))
    assert_response 201
    ticket_field = Helpdesk::TicketField.last
    match_json(custom_dropdown_field_pattern({}, ticket_field))
  end
end
