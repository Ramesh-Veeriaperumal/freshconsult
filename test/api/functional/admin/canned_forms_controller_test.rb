require_relative '../../test_helper'
require 'webmock/minitest'

class Admin::CannedFormsControllerTest < ActionController::TestCase
  include CannedFormsTestHelper

  def wrap_cname(params)
    { canned_form: params }
  end

  def setup
    super
    stub_request(:any, %r{^#{FORMSERV_CONFIG["formserv_url"]}.*?$}).to_rack(FakeFormserv)
    Account.current.add_feature(:canned_forms)
  end

  def teardown
    canned_forms = Account.current.canned_forms.all
    canned_forms.each do |form|
      form.destroy
    end
    Account.current.revoke_feature(:canned_forms)
    # unstub webmock request
    WebMock.allow_net_connect!
  end

  def test_create_handle
    canned_form = create_canned_form
    ticket = Account.current.tickets.last || create_ticket
    post :create_handle, construct_params({id: canned_form.id, version: 'private'}, ticket_id: ticket.display_id)
    assert_response 200
    match_json(canned_form_handle_pattern(Admin::CannedFormHandle.last))
  end

  def test_create_handle_without_admin_task_manage_ticket_privilege
    stub_privilege
    canned_form = create_canned_form
    ticket = Account.current.tickets.last || create_ticket
    post :create_handle, construct_params({ id: canned_form.id, version: 'private' }, ticket_id: ticket.display_id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    unstub_privilege
  end

  def test_create_handle_with_invalid_params
    canned_form = create_canned_form
    ticket = Account.current.tickets.last || create_ticket
    post :create_handle, construct_params({id: canned_form.id, version: 'private'}, invalid_id: ticket.display_id)
    assert_response 400
    match_json([bad_request_error_pattern('invalid_id', :invalid_field)])
  end

  def test_create_handle_with_invalid_ticket
    canned_form = create_canned_form
    ticket_id = Account.current.tickets.last.id + 1
    post :create_handle, construct_params({id: canned_form.id, version: 'private'}, ticket_id: ticket_id )
    assert_response 400
    match_json(request_error_pattern(:absent_in_db,  { resource: :record, attribute: :id }))
  end

  ###############FORM INDEX##############
  def test_index_canned_form
    3.times do
      create_canned_form
    end
    get :index, controller_params(version: 'private')
    canned_forms = Account.current.canned_forms.active_forms.limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
    assert_response 200
    pattern = []
    canned_forms.each do |c_form|
      pattern << canned_form_index_pattern(c_form)
    end
    match_json(pattern.ordered!)
  end

  def test_index_canned_form_without_manage_tickets_privilege
    stub_privilege
    3.times do
      create_canned_form
    end
    get :index, controller_params(version: 'private')
    canned_forms = Account.current.canned_forms.active_forms.limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    unstub_privilege
  end

  def test_index_canned_form_without_admin_tasks_privilege
    stub_privilege(true)
    3.times do
      create_canned_form
    end
    get :index, controller_params(version: 'private')
    canned_forms = Account.current.canned_forms.active_forms.limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
    assert_response 200
    pattern = []
    canned_forms.each do |c_form|
      pattern << canned_form_index_pattern(c_form)
    end
    match_json(pattern.ordered!)
    unstub_privilege
  end

  def test_index_canned_form_without_feature
    Account.current.revoke_feature(:canned_forms)
    get :index, controller_params(version: 'private')
    canned_forms = Account.current.canned_forms.active_forms.limit(ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page])
    assert_response 403
    match_json(request_error_pattern(:require_feature, feature: 'Canned Forms'))
    Account.current.unstub(:all_launched_features)
  end

  ###############CREATE FORM##############
  def test_create_canned_form_without_name
    request_param = form_payload
    request_param['name'] = nil
    post :create, construct_params(version: 'private', canned_form: request_param)
    assert_response 400
    match_json([bad_request_error_pattern('name', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: 'Null')])
  end

  def test_create_canned_form_with_invalid_type
    request_param = form_payload
    request_param['fields'] = {}
    post :create, construct_params(version: 'private', canned_form: request_param)
    assert_response 400
    match_json([bad_request_error_pattern('fields', :datatype_mismatch, expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'key/value pair')])
  end

  def test_create_canned_form_with_invalid_name
    request_param = form_payload
    request_param['name'] = 1234
    post :create, construct_params(version: 'private', canned_form: request_param)
    assert_response 400
    match_json([bad_request_error_pattern('name', :datatype_mismatch, expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer)])
  end

  def test_create_canned_form_with_duplicate_name
    request_param = form_payload
    request_param.delete 'fields'
    post :create, construct_params(version: 'private', canned_form: request_param)
    assert_response 200
    post :create, construct_params(version: 'private', canned_form: request_param)
    assert_response 409
    match_json([{"field" => "name", "message" => "It should be a unique value", "code" => "duplicate_value"}])
  end

  def test_create_canned_form_without_welcome_and_thankyou_text
    request_param = form_payload
    request_param['welcome_text'] = ""
    request_param['thankyou_text'] = ""
    post :create, construct_params(version: 'private', canned_form: request_param)
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_not_nil parsed_response['welcome_text']
    assert_not_nil parsed_response['thankyou_text']
  end

  def test_create_canned_form_with_invalid_field_name
    request_param = form_payload
    request_param['fields'] << {'name' => 'field_1', 'type' => 'ad', 'label' => nil, 'position' => 0}
    post :create, construct_params(version: 'private', canned_form: request_param)
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field('fields', 'name',:invalid_format, accepted: "#{CannedFormConstants::SUPPORTED_FIELDS.join(',')}")])
  end

  def test_create_canned_form_field_without_type
    request_param = form_payload
    request_param['fields'] << {'name' => 'paragraph_123525432'}
    post :create, construct_params(version: 'private', canned_form: request_param)
    assert_response 400
    match_json([bad_request_error_pattern('fields', [{"type":["can't be blank"],"label":["can't be blank"]}].to_json)])
  end

  def test_create_canned_form_zero_field
    request_param = form_payload
    request_param.delete 'fields'
    post :create, construct_params(version: 'private', canned_form: request_param)
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal parsed_response['name'], request_param['name']
    assert_equal parsed_response['welcome_text'], request_param['welcome_text']
    assert_equal parsed_response['thankyou_text'], request_param['thankyou_text']
  end

  def test_create_canned_form_dropdown_with_one_choice
    request_param = form_payload
    new_dropdown_field = dropdown_payload
    new_dropdown_field['choices'] = []
    new_dropdown_field['choices'] << choice_payload
    request_param['fields'] << new_dropdown_field
    post :create, construct_params(version: 'private', canned_form: request_param)
    assert_response 400
    match_json([bad_request_error_pattern('fields', :too_long_too_short, element_type: :choices, min_count: CannedFormConstants::MIN_CHOICE_LIMIT, current_count: new_dropdown_field['choices'].length, max_count: CannedFormConstants::MAX_CHOICE_LIMIT)])
  end

  def test_create_canned_form_dropdown_without_choice_value
    request_param = form_payload
    new_dropdown_field = dropdown_payload
    new_dropdown_field['choices'] = [choice_payload]
    new_dropdown_field['choices'] << { "custom" => true, "_destroy" => false, "type" => nil }
    request_param['fields'] << new_dropdown_field
    post :create, construct_params(version: 'private', canned_form: request_param)
    assert_response 400
    match_json([bad_request_error_pattern('fields', [{"fields"=>[{"value"=>["can't be blank"],"position"=>["can't be blank"]}]}].to_json)])
  end


  def test_create_canned_form
    request_param = form_payload
    post :create, construct_params(version: 'private', canned_form: request_param)
    assert_response 200
    parsed_response = JSON.parse(response.body)
    canned_form = Account.current.canned_forms.find(parsed_response['id'])
    assert_equal canned_form.name, request_param['name']
    assert_equal canned_form.welcome_text, request_param['welcome_text']
    assert_equal canned_form.thankyou_text, request_param['thankyou_text']
  end

  ###############UPDATE FORM##############
  def test_update_canned_form_version_mismatch
    canned_form = create_canned_form
    canned_form.fields.first.label = Faker::Lorem.characters(100)
    request_param = { 'name' => Faker::Name.name, 'version' => 99, 'fields' => JSON.parse(canned_form.fields.to_json) }
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 400
    match_json([{"field"=>"Formserv", "message"=>"Form version mismatch", "code"=>"invalid_value"}])
  end

  def test_update_canned_form_add_checkbox_field
    canned_form = create_canned_form
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version, 'fields' => JSON.parse(canned_form.fields.to_json) }
    field = checkbox_payload.merge({position: canned_form.fields.length + 1})
    request_param['fields'] << field
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal canned_form.fields.length + 1, parsed_response['fields'].length
    assert_not_nil parsed_response['fields'].detect{ |x| x['name'] === field['name'] }
  end

  def test_update_canned_form_without_privilege
    stub_privilege
    canned_form = create_canned_form
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version, 'fields' => JSON.parse(canned_form.fields.to_json) }
    field = checkbox_payload.merge(position: canned_form.fields.length + 1)
    request_param['fields'] << field
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    unstub_privilege
  end

  def test_update_canned_form_add_text_field
    canned_form = create_canned_form
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version, 'fields' => JSON.parse(canned_form.fields.to_json) }
    field = text_payload.merge({position: canned_form.fields.length + 1})
    request_param['fields'] << field
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal canned_form.fields.length + 1, parsed_response['fields'].length
    assert_not_nil parsed_response['fields'].detect{ |x| x['name'] === field['name'] }
  end

  def test_update_canned_form_add_paragraph_field
    canned_form = create_canned_form
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version, 'fields' => JSON.parse(canned_form.fields.to_json) }
    field = paragraph_payload.merge({position: canned_form.fields.length + 1})
    request_param['fields'] << field
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal canned_form.fields.length + 1, parsed_response['fields'].length
    assert_not_nil parsed_response['fields'].detect{ |x| x['name'] === field['name'] }
  end

  def test_update_canned_form_add_dropdown_field
    canned_form = create_canned_form
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version, 'fields' => JSON.parse(canned_form.fields.to_json) }
    field = dropdown_payload.merge({position: canned_form.fields.length + 1})
    request_param['fields'] << field
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal canned_form.fields.length + 1, parsed_response['fields'].length
    assert_not_nil parsed_response['fields'].detect{ |x| x['name'] === field['name'] }
  end

  def test_update_canned_form_with_max_field
    canned_form = create_canned_form
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version, 'fields' => JSON.parse(canned_form.fields.to_json) }
    CannedFormConstants::MAX_FIELD_LIMIT.times do |i|
      field = text_payload.merge({position: canned_form.fields.length + 1 + (i + 1)})
      request_param['fields'] << field
    end
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 400
    match_json([bad_request_error_pattern('fields', :too_long_too_short, element_type: :fields, min_count: CannedFormConstants::MIN_FIELD_LIMIT, current_count: request_param['fields'].length, max_count: CannedFormConstants::MAX_FIELD_LIMIT)])
  end

  def test_update_canned_form_delete_checkbox_field
    canned_form = create_canned_form
    field = canned_form.fields.find{|x| x.name.starts_with?('checkbox_')}
    field.deleted = true
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version, 'fields' => JSON.parse(canned_form.fields.to_json) }
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal canned_form.fields.length - 1 , parsed_response['fields'].length
    assert_nil parsed_response['fields'].detect{ |x| x['name'] === field.name }
  end

  def test_update_canned_form_delete_text_field
    canned_form = create_canned_form
    field = canned_form.fields.find{|x| x.name.starts_with?('text_')}
    field.deleted = true
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version, 'fields' => JSON.parse(canned_form.fields.to_json) }
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal canned_form.fields.length - 1 , parsed_response['fields'].length
    assert_nil parsed_response['fields'].detect{ |x| x['name'] === field.name }
  end

  def test_update_canned_form_delete_paragraph_field
    canned_form = create_canned_form
    field = canned_form.fields.find{|x| x.name.starts_with?('paragraph_')}
    field.deleted = true
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version, 'fields' => JSON.parse(canned_form.fields.to_json) }
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal canned_form.fields.length - 1 , parsed_response['fields'].length
    assert_nil parsed_response['fields'].detect{ |x| x['name'] === field.name }
  end

  def test_update_canned_form_delete_dropdown_field
    canned_form = create_canned_form
    field = canned_form.fields.find{|x| x.name.starts_with?('dropdown_')}
    field.deleted = true
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version, 'fields' => JSON.parse(canned_form.fields.to_json) }
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_equal canned_form.fields.length - 1 , parsed_response['fields'].length
    assert_nil parsed_response['fields'].detect{ |x| x['name'] === field.name }
  end

  def test_update_canned_form_delete_all_fields
    canned_form = create_canned_form
    canned_form.fields.each do |field|
      field.deleted = true
    end
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version, 'fields' => JSON.parse(canned_form.fields.to_json) }
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 400
    parsed_response = JSON.parse(response.body)
    assert_equal 0, parsed_response['fields'].length
    match_json([bad_request_error_pattern('fields', :too_long_too_short, element_type: :fields, min_count: CannedFormConstants::MIN_FIELD_LIMIT, current_count: parsed_response['fields'].length, max_count: CannedFormConstants::MAX_FIELD_LIMIT)])
  end

  def test_update_canned_form_dropdown_field_with_new_choice
    canned_form = create_canned_form
    updated_field = nil
    canned_form.fields.each do |field|
      field_name = field.name.split('_')[0]
      if CannedFormConstants::MULTI_CHOICE_FIELDS.include? field_name
        updated_field = field
        field.choices << choice_payload
      end
    end
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version, 'fields' => JSON.parse(canned_form.fields.to_json) }
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 200
    parsed_response = JSON.parse(response.body)
    field = parsed_response['fields'].detect { |x| x['id'] === updated_field.id}
    assert_equal field['choices'].length, updated_field.choices.length
  end

  def test_update_canned_form_dropdown_with_one_choice
    canned_form = create_canned_form
    new_field = dropdown_payload
    new_field['choices'] = []
    new_field['choices'] << choice_payload
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version, 'fields' => JSON.parse(canned_form.fields.to_json) }
    request_param['fields'] << new_field
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 400
    match_json([bad_request_error_pattern('fields', :too_long_too_short, element_type: :choices, min_count: CannedFormConstants::MIN_CHOICE_LIMIT, current_count: new_field['choices'].length, max_count: CannedFormConstants::MAX_CHOICE_LIMIT)])
  end

  def test_update_canned_form_dropdown_with_max_choice
    canned_form = create_canned_form
    new_field = dropdown_payload
    new_field['choices'] = []
    iteration = CannedFormConstants::MAX_CHOICE_LIMIT + 1
    iteration.times do
      new_field['choices'] << choice_payload
    end
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version, 'fields' => JSON.parse(canned_form.fields.to_json) }
    request_param['fields'] << new_field
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 400
    match_json([bad_request_error_pattern('fields', :too_long_too_short, element_type: :choices, min_count: CannedFormConstants::MIN_CHOICE_LIMIT, current_count: new_field['choices'].length, max_count: CannedFormConstants::MAX_CHOICE_LIMIT)])
  end

  def test_update_canned_form_dropdown_with_one_deleted_choice
    canned_form = create_canned_form
    field_id = ''
    canned_form.fields.each do |field|
      return if field_id.present?
      field.choices.first['_destroy'] = true if field.choices.present?
      field_id = field.id
      choice_length = field.choices.length
    end
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version, 'fields' => JSON.parse(canned_form.fields.to_json) }
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 200
    parsed_response = JSON.parse(response.body)
    result_choice_length = parsed_response.detect{|x| x['id'] == field_id }['choice'].length
    assert_equal choice_length, result_choice_length+1
  end

  def test_update_canned_form_dropdown_with_deleted_choice_and_value_null
    canned_form = create_canned_form
    field_id = ''
    canned_form.fields.each do |field|
      return if field_id.present?
      if field.choices.present?
        field.choices.first['_destroy'] = true
        field.choices.first['value'] = ''
      end
      field_id = field.id
      choice_length = field.choices.length
    end
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version, 'fields' => JSON.parse(canned_form.fields.to_json) }
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 200
    parsed_response = JSON.parse(response.body)
    result_choice_length = parsed_response.detect{|x| x['id'] == field_id }['choice'].length
    assert_equal choice_length, result_choice_length+1
  end

  def test_update_canned_form_dropdown_with_all_choices_deleted
    canned_form = create_canned_form
    fields = JSON.parse(canned_form.fields.to_json)
    fields.each do |field|
      if field['choices'].present?
        field['choices'].each { |x| x['_destroy'] = true }
        choice_length = field['choices'].length
        field_id = field['id']
      end
    end
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version, 'fields' => fields }
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 400
    match_json([bad_request_error_pattern('fields', :too_long_too_short, element_type: :choices, min_count: CannedFormConstants::MIN_CHOICE_LIMIT, current_count: 0, max_count: CannedFormConstants::MAX_CHOICE_LIMIT)])
  end

  def test_update_canned_form_fields_label_and_position
    canned_form = create_canned_form
    fields = JSON.parse(canned_form.fields.to_json)
    update_params = update_form_label_position_and_placeholder
    fields.each_with_index do |field, index|
      update_hash = update_params[index]
      if field['choices'].present?
        field['choices'].each_with_index do |choice, c_index|
          choice.merge!(update_hash['choices'][c_index])
        end
        update_hash.delete 'choices'
        field['choices'].sort_by! { |c| c['position'] }
      end
      field.merge!(update_hash)
    end
    request_param = { 'version' => canned_form.version, 'fields' => fields }
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 200
    request_param['version'] += 1
    match_json(canned_form_pattern(canned_form, request_param))
  end

  def test_update_canned_form
    canned_form = create_canned_form
    request_param = { 'name' => Faker::Name.name, 'version' => canned_form.version }
    put :update, construct_params(version: 'private', id: canned_form.id, canned_form: request_param)
    assert_response 200
    request_param['version'] += 1
    match_json(canned_form_pattern(canned_form, request_param))
  end

  ###############SHOW FORM##############
  def test_show_canned_form
    canned_form = create_canned_form
    get :show, controller_params(version: 'private', id: canned_form.id)
    assert_response 200
    match_json(canned_form_pattern(canned_form))
  end

  def test_show_canned_form_without_manage_tickets_privilege
    stub_privilege
    canned_form = create_canned_form
    get :show, controller_params(version: 'private', id: canned_form.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    unstub_privilege
  end

  def test_show_canned_form_without_manage_admin_privilege
    stub_privilege(true)
    canned_form = create_canned_form
    get :show, controller_params(version: 'private', id: canned_form.id)
    assert_response 200
    match_json(canned_form_pattern(canned_form))
    unstub_privilege
  end

  def test_show_canned_form_with_invalid_id
    canned_form = create_canned_form
    get :show, controller_params(version: 'private', id: 999)
    assert_response 404
    assert_equal ' ', @response.body
  end

  ###############DESTROY FORM##############
  def test_destroy_canned_form
    canned_form = create_canned_form
    delete :destroy, construct_params({ version: 'private' }, false).merge(id: canned_form.id)
    assert_response 204
    canned_form.reload
    assert_equal true, canned_form.deleted
    assert_equal ' ', @response.body
  end

  def test_destroy_canned_form_with_invalid_id
    canned_form = create_canned_form
    delete :destroy, controller_params(version: 'private', id: 999)
    assert_response 404
    assert_equal ' ', @response.body
  end

  private

    def stub_privilege(manage_tickets = false)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
      User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(manage_tickets)
    end

    def unstub_privilege
      User.any_instance.unstub(:privilege?)
    end
end
