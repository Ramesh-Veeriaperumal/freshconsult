require_relative '../unit_test_helper'

class InstalledApplicationValidationTest < ActionView::TestCase

  def get_request_payload(event = nil, payload_type = nil)
    {
      event: event,
      payload: { 
        type: payload_type || Faker::Lorem.characters(10), 
        value: Faker::Internet.email
      }
    }
  end

  def get_application(app_name)
    app = Integrations::InstalledApplication.new
    app.application = Integrations::Application.new
    app.application.name = app_name
    app
  end

  def test_value_valid
    installed_app = InstalledApplicationValidation.new({ name: 'harvest' }, nil)
    assert installed_app.valid?
  end

  def test_value_invalid
    installed_app = InstalledApplicationValidation.new({ name: nil }, nil)
    refute installed_app.valid?(:index)
  end

  def test_fetch_with_valid_event_and_payload
    app = get_application('salesforce')
    installed_app = InstalledApplicationValidation.new(
      get_request_payload("fetch_user_selected_fields", "contact"), app)
    assert installed_app.valid?(:fetch)
  end

  def test_fetch_on_nil_event_value
    request_payload = get_request_payload(nil, "contact")
    request_payload[:event] = nil
    installed_app = InstalledApplicationValidation.new(request_payload, nil)
    refute installed_app.valid?(:fetch)
    error_messages = installed_app.errors.full_messages
    assert error_messages.include? "Event not_included"
  end

  def test_fetch_on_invalid_event_value
    request_payload = get_request_payload(Faker::Lorem.characters(20), "contact")
    request_payload[:event] = nil
    installed_app = InstalledApplicationValidation.new(request_payload, nil)
    refute installed_app.valid?(:fetch)
    error_messages = installed_app.errors.full_messages
    assert error_messages.include? "Event not_included"
  end

  def test_fetch_without_payload_value
    app = get_application('salesforce')
    installed_app = InstalledApplicationValidation.new(
      { event: 'fetch_user_selected_fields' }, app)
    refute installed_app.valid?(:fetch)
    error_messages = installed_app.errors.full_messages
    assert error_messages.include? "Payload datatype_mismatch"
  end

  def test_fetch_on_nil_payload
    app = get_application('salesforce')
    installed_app = InstalledApplicationValidation.new(
      { event: 'fetch_user_selected_fields', payload: nil }, app)
    refute installed_app.valid?(:fetch)
    error_messages = installed_app.errors.full_messages
    assert error_messages.include? "Payload datatype_mismatch"
  end

  def test_fetch_on_invalid_type_value_in_payload_param
    app = get_application('salesforce')
    request_payload = get_request_payload("fetch_user_selected_fields", 
      Faker::Lorem.characters(10))
    installed_app = InstalledApplicationValidation.new(request_payload, app)
    refute installed_app.valid?(:fetch)
    error_messages = installed_app.errors.full_messages
    assert error_messages.include? "Payload not_included"
    assert_equal({:event=>{}, :payload=>{:list=>"contact,lead,account,opportunity,deal", 
      :nested_field=>:type}}, installed_app.error_options)
  end

  def test_fetch_without_type_value_in_payload_param
    app = get_application('salesforce')
    request_payload = get_request_payload("fetch_user_selected_fields")
    request_payload[:payload].delete(:type)
    installed_app = InstalledApplicationValidation.new(request_payload, app)
    refute installed_app.valid?(:fetch)
    error_messages = installed_app.errors.full_messages
    assert error_messages.include? "Payload not_included"
    assert_equal({ event: {}, payload: { list: "contact,lead,account,opportunity,deal", 
      code: :missing_field, nested_field: :type } }, installed_app.error_options)
  end

  def test_fetch_with_event_as_integrated_resource
    app = get_application('salesforce')
    request_payload = get_request_payload("integrated_resource")
    request_payload[:payload] = { ticket_id: rand(20) }
    installed_app = InstalledApplicationValidation.new(request_payload, app)
    assert installed_app.valid?(:fetch)
  end

  def test_fetch_integrated_resource_without_ticket_id
    app = get_application('salesforce')
    request_payload = get_request_payload("integrated_resource")
    request_payload[:payload] = {}
    installed_app = InstalledApplicationValidation.new(request_payload, app)
    refute installed_app.valid?(:fetch)
    error_messages = installed_app.errors.full_messages
    assert error_messages.include? "Payload datatype_mismatch"
    assert_equal({ event: {}, payload: { expected_data_type: Integer, 
      code: :missing_field, nested_field: :ticket_id}},installed_app.error_options)
  end

  def test_install_apps_without_config
    installed_app = InstalledApplicationValidation.new({ 'name' => 'freshsales' }, nil)
    refute installed_app.valid?(:create)
    error_messages = installed_app.errors.full_messages
    assert error_messages.include? 'Configs missing_field'
    assert_equal({ name: {}, configs: { code: :missing_field } }, installed_app.error_options)
  end

  def test_install_apps_without_domain
    installed_app = InstalledApplicationValidation.new({ 'name' => 'freshsales', 'configs' => { 'ghostvalue' => '.freshsales.io', 'auth_token' => 'v_GNcz8s2BmhzOVsp4Oe_w' } }, nil)
    refute installed_app.valid?(:create)
    error_messages = installed_app.errors.full_messages
    assert error_messages.include? 'Domain missing_field'
  end

  def test_install_apps_without_ghostvalue
    installed_app = InstalledApplicationValidation.new({ 'name' => 'freshsales', 'configs' => { 'domain' => 'ramkumar', 'auth_token' => 'v_GNcz8s2BmhzOVsp4Oe_w' } }, nil)
    refute installed_app.valid?(:create)
    error_messages = installed_app.errors.full_messages
    assert error_messages.include? 'Ghostvalue missing_field'
  end

  def test_install_apps_without_authtoken
    installed_app = InstalledApplicationValidation.new({ 'name' => 'freshsales', 'configs' => { 'domain' => 'ramkumar', 'ghostvalue' => '.freshsales.io' } }, nil)
    refute installed_app.valid?(:create)
    error_messages = installed_app.errors.full_messages
    assert error_messages.include? 'Auth token missing_field'
  end
end