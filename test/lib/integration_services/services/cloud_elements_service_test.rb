require_relative '../../../api/unit_test_helper'
require Rails.root.join('test', 'api', 'helpers', 'ticket_fields_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'installed_applications_test_helper.rb')
require 'webmock/minitest'
class CloudElementsServiceTest < ActionView::TestCase
  include TicketFieldsTestHelper
  include InstalledApplicationsTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    VaRule.any_instance.stubs(:save!).returns('1')
  end

  def teardown
    super
    Account.unstub(:current)
    VaRule.any_instance.unstub(:save!)
  end

  def test_receive_create_opportunity
    IntegrationServices::Services::CloudElements::Hub::Crm::OpportunityResource.any_instance.stubs(:create).returns('created successfully')
    opportunity = ::IntegrationServices::Services::CloudElementsService.new(nil, { type: 'test' }, {}).receive_create_opportunity
    assert_equal 'created successfully', opportunity
  end

  def test_receive_create_opportunity_error
    IntegrationServices::Services::CloudElements::Hub::Crm::OpportunityResource.any_instance.stubs(:create).raises(::IntegrationServices::Errors::RemoteError.new('Remote error', 400))
    IntegrationServices::Services::CloudElementsService.any_instance.stubs(:error).returns('error')
    opportunity = ::IntegrationServices::Services::CloudElementsService.new(nil, { type: 'test' }, {}).receive_create_opportunity
    assert_equal 'error', opportunity
  end

  def test_receive_link_opportunity
    app = Integrations::InstalledApplication.new
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).returns(Integrations::InstalledApplication.new)
    Integrations::InstalledApplication.any_instance.stubs(:create).returns(true)
    link_opp = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_link_opportunity
    assert_equal true, link_opp
  end

  def test_receive_link_opportunity_error
    app = Integrations::InstalledApplication.new
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).raises(Exception.new('Exception'))
    IntegrationServices::Services::CloudElementsService.any_instance.stubs(:error).returns('error')
    link_opp = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_link_opportunity
    assert_equal 'error', link_opp
  end

  def test_receive_unlink_opportunity
    app = Integrations::InstalledApplication.new
    link_opp = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_unlink_opportunity
    assert_equal true, link_opp.key?(:error)
  end

  def test_receive_unlink_opportunity_existing_resource
    app = Integrations::InstalledApplication.new
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).returns(Integrations::InstalledApplication.new)
    Integrations::InstalledApplication.any_instance.stubs(:where).returns([Integrations::InstalledApplication.new])
    Integrations::InstalledApplication.any_instance.stubs(:destroy).returns(true)
    link_opp = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_unlink_opportunity
    assert_equal true, link_opp
  end

  def test_receive_unlink_opportunity_error
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElementsService.any_instance.stubs(:error).returns('error')
    Integrations::InstalledApplication.any_instance.stubs(:integrated_resources).raises(Exception.new('exception'))
    link_opp = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_unlink_opportunity
    assert_equal 'error', link_opp
  end

  def test_receive_uninstall
    app = Integrations::InstalledApplication.new
    Integrations::InstalledApplication.any_instance.stubs(:application).returns(Integrations::InstalledApplication.new)
    Integrations::InstalledApplication.any_instance.stubs(:name).returns('test application')
    Integrations::CloudElementsDeleteWorker.any_instance.stubs(:perform).returns(true)
    Integrations::CloudElementsDeleteWorker.stubs(:perform_async).returns(true)
    unst = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_uninstall
    assert_equal true, unst
  end

  def test_receive_uninstall_errors
    app = Integrations::InstalledApplication.new
    Integrations::InstalledApplication.any_instance.stubs(:application).returns(Integrations::InstalledApplication.new)
    Integrations::InstalledApplication.any_instance.stubs(:name).returns('test application')
    Integrations::CloudElementsDeleteWorker.any_instance.stubs(:perform).returns(true)
    Integrations::CloudElementsDeleteWorker.stubs(:perform_async).raises(Exception.new('exception'))
    IntegrationServices::Services::CloudElementsService.any_instance.stubs(:current_account).returns(Account.first)
    FreshdeskErrorsMailer.stubs(:error_email).returns(true)
    unst = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_uninstall
    assert_equal true, unst
  end

  def test_class_methods
    http_options = IntegrationServices::Services::CloudElementsService.default_http_options
    title = IntegrationServices::Services::CloudElementsService.title
    assert_equal true, http_options.present?
    assert_equal 'cloud_elements', title
  end

  def test_fetch_server_url
    app = Integrations::InstalledApplication.new
    url = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).server_url
    assert_equal Integrations::CLOUD_ELEMENTS_URL, url
  end

  def test_sf_receive_ticket_sync_install
    app = Integrations::InstalledApplication.new
    sync_install = ::IntegrationServices::Services::SalesforceV2Service.new(app, { type: 'test' }, {}).receive_ticket_sync_install
    assert_not_equal true, sync_install
  end

  def test_receive_create_custom_object
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Hub::Crm::ContactResource.any_instance.stubs(:find).returns([{ Name: 'Test name', Id: '1' }.stringify_keys!])
    IntegrationServices::Services::CloudElements::Hub::Crm::AccountResource.any_instance.stubs(:find).returns([{ Id: '1' }.stringify_keys!])
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:create).returns({ Id: '1' }.stringify_keys!)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:update).returns(nil)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:check_fields_synced?).returns(true)
    custom_obj = ::IntegrationServices::Services::SalesforceV2Service.new(app, { type: 'test', data_object: Account.first.tickets.last }, {}).receive_create_custom_object
    assert_equal nil, custom_obj
  end

  def test_receive_create_custom_object_account_id
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Hub::Crm::ContactResource.any_instance.stubs(:find).returns([{ Name: 'Test name', Id: '1', AccountId: '1' }.stringify_keys!])
    IntegrationServices::Services::CloudElements::Hub::Crm::AccountResource.any_instance.stubs(:find).returns({ Name: 'test_name' }.stringify_keys!)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:create).returns({ Id: '1' }.stringify_keys!)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:update).returns(nil)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:check_fields_synced?).returns(true)
    custom_obj = ::IntegrationServices::Services::SalesforceV2Service.new(app, { type: 'test', data_object: Account.first.tickets.last }, {}).receive_create_custom_object
    assert_equal nil, custom_obj
  end

  def test_receive_create_custom_object_no_contact
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Hub::Crm::ContactResource.any_instance.stubs(:find).returns(nil)
    IntegrationServices::Services::CloudElements::Hub::Crm::ContactResource.any_instance.stubs(:create).returns({ Name: 'Test name', Id: '1' }.stringify_keys!)
    IntegrationServices::Services::CloudElements::Hub::Crm::AccountResource.any_instance.stubs(:find).returns([{ Id: '1' }.stringify_keys!])
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:create).returns({ Id: '1' }.stringify_keys!)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:update).returns(nil)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:check_fields_synced?).returns(true)
    User.any_instance.stubs(:helpdesk_agent).returns(true)
    custom_obj = ::IntegrationServices::Services::SalesforceV2Service.new(app, { type: 'test', data_object: Account.first.tickets.last }, {}).receive_create_custom_object
    assert_equal nil, custom_obj
  end

  def test_receive_create_custom_object_not_found_error
    app = Integrations::InstalledApplication.new
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: { ticket_sync_option: 0 }.stringify_keys!)
    Integrations::InstalledApplication.any_instance.stubs(:save!).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:va_rules).returns([VaRule.first])
    IntegrationServices::Services::SalesforceV2Service.any_instance.stubs(:error).returns('err')
    VaRule.any_instance.stubs(:save).returns(true)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:check_fields_synced?).returns(false)
    custom_obj = ::IntegrationServices::Services::SalesforceV2Service.new(app, { type: 'test' }, {}).receive_create_custom_object
    assert_equal nil, custom_obj
  end

  def test_receive_create_custom_object_error
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:check_fields_synced?).raises(Exception.new('Exception'))
    custom_obj = ::IntegrationServices::Services::SalesforceV2Service.new(app, { type: 'test' }, {}).receive_create_custom_object
  rescue Exception => e
    assert_equal nil, custom_obj
  end

  def test_receive_update_custom_object
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:check_fields_synced?).returns(true)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:find).returns([{ Id: '1' }.stringify_keys!])
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:update).returns(nil)
    custom_obj = ::IntegrationServices::Services::SalesforceV2Service.new(app, { type: 'test', data_object: Account.first.tickets.last }, {}).receive_update_custom_object
    assert_equal nil, custom_obj
  end

  def test_receive_update_custom_object_tkt_exception
    app = Integrations::InstalledApplication.new
    Integrations::InstalledApplication.any_instance.stubs(:configs).returns(inputs: { ticket_sync_option: 0 }.stringify_keys!)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:check_fields_synced?).returns(false)
    Integrations::InstalledApplication.any_instance.stubs(:save!).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:va_rules).returns([VaRule.first])
    IntegrationServices::Services::SalesforceV2Service.any_instance.stubs(:error).returns('err')
    VaRule.any_instance.stubs(:save).returns(true)
    custom_obj = ::IntegrationServices::Services::SalesforceV2Service.new(app, { type: 'test', data_object: Account.first.tickets.last }, {}).receive_update_custom_object
    assert_equal nil, custom_obj
  end

  def test_receive_update_custom_object_not_found
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:check_fields_synced?).returns(true)
    IntegrationServices::Services::CloudElements::Hub::Crm::ContactResource.any_instance.stubs(:find).returns([{ Name: 'Test name', Id: '1' }.stringify_keys!])
    IntegrationServices::Services::CloudElements::Hub::Crm::AccountResource.any_instance.stubs(:find).returns([{ Id: '1' }.stringify_keys!])
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:find).returns([])
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:create).returns({ Id: '1' }.stringify_keys!)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:update).returns(nil)
    custom_obj = ::IntegrationServices::Services::SalesforceV2Service.new(app, { type: 'test', data_object: Account.first.tickets.last }, {}).receive_update_custom_object
    assert_equal nil, custom_obj
  end

  def test_receive_update_custom_object_with_503_from_cloud_elements
    app = Integrations::InstalledApplication.new
    success_response = OpenStruct.new('status' => 200)
    valid_failure_response = OpenStruct.new('status' => 503)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:http_get).returns(valid_failure_response, valid_failure_response).then.returns(success_response)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:find).returns([{ Id: '1' }.stringify_keys!])
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:update).returns(nil)
    custom_obj = ::IntegrationServices::Services::SalesforceV2Service.new(app, { type: 'test', data_object: Account.first.tickets.last }, {}).receive_update_custom_object
    assert_equal nil, custom_obj
  ensure
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.unstub
  end

  def test_receive_update_custom_object_with_504_from_cloud_elements
    app = Integrations::InstalledApplication.new
    success_response = OpenStruct.new('status' => 200)
    valid_failure_response = OpenStruct.new('status' => 504)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:http_get).returns(valid_failure_response, valid_failure_response).then.returns(success_response)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:find).returns([{ Id: '1' }.stringify_keys!])
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:update).returns(nil)
    custom_obj = ::IntegrationServices::Services::SalesforceV2Service.new(app, { type: 'test', data_object: Account.first.tickets.last }, {}).receive_update_custom_object
    assert_equal nil, custom_obj
  ensure
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.unstub
  end

  def test_receive_update_custom_object_with_500_from_cloud_elements
    valid_failure_response = OpenStruct.new('status' => 503)
    failure_response = OpenStruct.new('status' => 500)
    VaRule.any_instance.stubs(:save).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:save).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:save!).returns(true)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:http_get).returns(valid_failure_response, valid_failure_response).then.returns(failure_response)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:find).returns([{ Id: '1' }.stringify_keys!])
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:update).returns(nil)
    IntegrationServices::Services::SalesforceV2Service.any_instance.stubs(:error).returns('dummy_error')
    app = create_application('salesforce_v2')
    app.configs[:inputs]['ticket_sync_option'] = '1'
    app.save
    custom_obj = ::IntegrationServices::Services::SalesforceV2Service.new(app, { type: 'test', data_object: Account.first.tickets.last }, {}).receive_update_custom_object
    assert_equal nil, custom_obj
    assert_equal '0', app.configs[:inputs]['ticket_sync_option']
  ensure
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.unstub
    IntegrationServices::Services::SalesforceV2Service.any_instance.unstub
    Integrations::InstalledApplication.any_instance.unstub
  end

  def test_receive_update_custom_object_with_500_from_cloud_elements_with_failure_response_504
    valid_failure_response = OpenStruct.new('status' => 504)
    failure_response = OpenStruct.new('status' => 500)
    VaRule.any_instance.stubs(:save).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:save).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:save!).returns(true)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:http_get).returns(valid_failure_response, valid_failure_response).then.returns(failure_response)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:find).returns([{ Id: '1' }.stringify_keys!])
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:update).returns(nil)
    IntegrationServices::Services::SalesforceV2Service.any_instance.stubs(:error).returns('dummy_error')
    app = create_application('salesforce_v2')
    app.configs[:inputs]['ticket_sync_option'] = '1'
    app.save
    custom_obj = ::IntegrationServices::Services::SalesforceV2Service.new(app, { type: 'test', data_object: Account.first.tickets.last }, {}).receive_update_custom_object
    assert_equal nil, custom_obj
    assert_equal '0', app.configs[:inputs]['ticket_sync_option']
  ensure
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.unstub
    IntegrationServices::Services::SalesforceV2Service.any_instance.unstub
    Integrations::InstalledApplication.any_instance.unstub
  end

  def test_receive_update_custom_object_with_503_from_cloud_elements_after_retries
    valid_failure_response = OpenStruct.new('status' => 503)
    VaRule.any_instance.stubs(:save).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:save).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:save!).returns(true)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:http_get).returns(valid_failure_response, valid_failure_response).then.returns(valid_failure_response)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:find).returns([{ Id: '1' }.stringify_keys!])
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:update).returns(nil)
    IntegrationServices::Services::SalesforceV2Service.any_instance.stubs(:error).returns('dummy_error')
    app = create_application('salesforce_v2')
    app.configs[:inputs]['ticket_sync_option'] = '1'
    app.save
    custom_obj = ::IntegrationServices::Services::SalesforceV2Service.new(app, { type: 'test', data_object: Account.first.tickets.last }, {}).receive_update_custom_object
    assert_equal nil, custom_obj
    assert_equal '0', app.configs[:inputs]['ticket_sync_option']
  ensure
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.unstub
    IntegrationServices::Services::SalesforceV2Service.any_instance.unstub
    Integrations::InstalledApplication.any_instance.unstub
  end

  def test_receive_update_custom_object_with_504_from_cloud_elements_after_retries
    valid_failure_response = OpenStruct.new('status' => 504)
    VaRule.any_instance.stubs(:save).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:save).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:save!).returns(true)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:http_get).returns(valid_failure_response, valid_failure_response).then.returns(valid_failure_response)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:find).returns([{ Id: '1' }.stringify_keys!])
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:update).returns(nil)
    IntegrationServices::Services::SalesforceV2Service.any_instance.stubs(:error).returns('dummy_error')
    app = create_application('salesforce_v2')
    app.configs[:inputs]['ticket_sync_option'] = '1'
    app.save
    custom_obj = ::IntegrationServices::Services::SalesforceV2Service.new(app, { type: 'test', data_object: Account.first.tickets.last }, {}).receive_update_custom_object
    assert_equal nil, custom_obj
    assert_equal '0', app.configs[:inputs]['ticket_sync_option']
  ensure
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.unstub
    IntegrationServices::Services::SalesforceV2Service.any_instance.unstub
    Integrations::InstalledApplication.any_instance.unstub
  end

  def test_receive_update_custom_object_when_it_succeeds
    success_response = OpenStruct.new('status' => 200)
    valid_failure_response = OpenStruct.new('status' => 503)
    VaRule.any_instance.stubs(:save).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:save).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:save!).returns(true)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:http_get).returns(success_response, valid_failure_response).then.returns(valid_failure_response)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:find).returns([{ Id: '1' }.stringify_keys!])
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:update).returns(nil)
    app = create_application('salesforce_v2')
    app.configs[:inputs]['ticket_sync_option'] = '1'
    app.save
    custom_obj = ::IntegrationServices::Services::SalesforceV2Service.new(app, { type: 'test', data_object: Account.first.tickets.last }, {}).receive_update_custom_object
    assert_equal nil, custom_obj
    assert_equal '1', app.configs[:inputs]['ticket_sync_option']
  ensure
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.unstub
    IntegrationServices::Services::SalesforceV2Service.any_instance.unstub
    Integrations::InstalledApplication.any_instance.unstub
  end

  def test_receive_update_custom_object_when_it_succeeds_with_retry_failure_response_504
    success_response = OpenStruct.new('status' => 200)
    valid_failure_response = OpenStruct.new('status' => 504)
    VaRule.any_instance.stubs(:save).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:save).returns(true)
    Integrations::InstalledApplication.any_instance.stubs(:save!).returns(true)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:http_get).returns(success_response, valid_failure_response).then.returns(valid_failure_response)
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:find).returns([{ Id: '1' }.stringify_keys!])
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.stubs(:update).returns(nil)
    app = create_application('salesforce_v2')
    app.configs[:inputs]['ticket_sync_option'] = '1'
    app.save
    custom_obj = ::IntegrationServices::Services::SalesforceV2Service.new(app, { type: 'test', data_object: Account.first.tickets.last }, {}).receive_update_custom_object
    assert_equal nil, custom_obj
    assert_equal '1', app.configs[:inputs]['ticket_sync_option']
  ensure
    IntegrationServices::Services::CloudElements::Hub::Crm::FreshdeskTicketObjectResource.any_instance.unstub
    IntegrationServices::Services::SalesforceV2Service.any_instance.unstub
    Integrations::InstalledApplication.any_instance.unstub
  end

  def test_receive_create_element_instance
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Platform::ElementInstanceResource.any_instance.stubs(:create_instance).returns(true)
    element_instance = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_create_element_instance
    assert_equal true, element_instance
  end

  def test_receive_delete_element_instance
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Platform::ElementInstanceResource.any_instance.stubs(:delete_instance).returns(true)
    element_instance = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_delete_element_instance
    assert_equal true, element_instance
  end

  def test_receive_get_element_configuration
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Platform::ElementInstanceResource.any_instance.stubs(:get_configuration).returns(true)
    element_instance = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_get_element_configuration
    assert_equal true, element_instance
  end

  def test_receive_update_element_configuration
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Platform::ElementInstanceResource.any_instance.stubs(:update_configuration).returns(true)
    element_instance = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_update_element_configuration
    assert_equal true, element_instance
  end

  def test_receive_object_metadata
    app = Integrations::InstalledApplication.new
    ::IntegrationServices::Services::CloudElements::CloudElementsResource.any_instance.stubs(:get_fields).returns(true)
    object_meta = ::IntegrationServices::Services::CloudElementsService.new(app, { object: 'cloud_elements' }, {}).receive_object_metadata
    assert_equal true, object_meta
  end

  def test_receive_create_instance_object_definition
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Platform::ObjectResource.any_instance.stubs(:create_instance_level_object_definition).returns(true)
    inst_obj = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_create_instance_object_definition
    assert_equal true, inst_obj
  end

  def test_receive_update_instance_object_definition
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Platform::ObjectResource.any_instance.stubs(:update_instance_level_object_definition).returns(true)
    inst_obj = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_update_instance_object_definition
    assert_equal true, inst_obj
  end

  def test_receive_create_instance_transformation
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Platform::TransformationResource.any_instance.stubs(:create_instance_level_transformation).returns(true)
    inst_transformation = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_create_instance_transformation
    assert_equal true, inst_transformation
  end

  def test_receive_update_instance_transformation
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Platform::TransformationResource.any_instance.stubs(:update_instance_level_transformation).returns(true)
    inst_transformation = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_update_instance_transformation
    assert_equal true, inst_transformation
  end

  def test_receive_create_formula_instance
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Platform::FormulaResource.any_instance.stubs(:create_instance).returns(true)
    formula_inst = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_create_formula_instance
    assert_equal true, formula_inst
  end

  def test_receive_update_formula_instance
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Platform::FormulaResource.any_instance.stubs(:update_instance).returns(true)
    formula_inst = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_update_formula_instance
    assert_equal true, formula_inst
  end

  def test_receive_delete_formula_instance
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Platform::FormulaResource.any_instance.stubs(:delete_instance).returns(true)
    formula_inst = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_delete_formula_instance
    assert_equal true, formula_inst
  end

  def test_receive_get_formula_executions
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Platform::FormulaResource.any_instance.stubs(:get_execution).returns(true)
    formula_inst = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_get_formula_executions
    assert_equal true, formula_inst
  end

  def test_receive_get_formula_failure_step_id
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Platform::FormulaResource.any_instance.stubs(:get_failure_step_id).returns(true)
    formula_inst = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_get_formula_failure_step_id
    assert_equal true, formula_inst
  end

  def test_receive_get_formula_failure_reason
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Platform::FormulaResource.any_instance.stubs(:get_failure_reason).returns(true)
    formula_inst = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_get_formula_failure_reason
    assert_equal true, formula_inst
  end

  def test_receive_get_contact_account_name
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Hub::Crm::AccountResource.any_instance.stubs(:get_account_name).returns('first')
    acc_inst = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_get_contact_account_name
    assert_equal 'first', acc_inst
  end

  def test_receive_get_contact_account_id
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Hub::Crm::ContactResource.any_instance.stubs(:get_selected_fields).returns(1)
    acc_inst = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_get_contact_account_id
    assert_equal 1, acc_inst
  end

  def test_receive_integrated_resource
    app = Integrations::InstalledApplication.new
    integrated = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'test' }, {}).receive_integrated_resource
    assert_equal false, integrated.present?
  end

  def test_receive_fetch_user_selected_fields_lead_resource
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Hub::Crm::LeadResource.any_instance.stubs(:get_selected_fields).returns(true)
    sel_field = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'lead' }, {}).receive_fetch_user_selected_fields
    assert_equal true, sel_field
  end

  def test_receive_fetch_user_selected_fields_contract_resource
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Hub::Crm::ContractResource.any_instance.stubs(:get_selected_fields).returns(true)
    sel_field = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'contract' }, {}).receive_fetch_user_selected_fields
    assert_equal true, sel_field
  end

  def test_receive_fetch_user_selected_fields_order_resource
    app = Integrations::InstalledApplication.new
    IntegrationServices::Services::CloudElements::Hub::Crm::OrderResource.any_instance.stubs(:get_selected_fields).returns(true)
    sel_field = ::IntegrationServices::Services::CloudElementsService.new(app, { type: 'order' }, {}).receive_fetch_user_selected_fields
    assert_equal true, sel_field
  end
end
