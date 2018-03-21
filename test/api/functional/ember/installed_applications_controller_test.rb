require_relative '../../test_helper'
class Ember::InstalledApplicationsControllerTest < ActionController::TestCase
  include InstalledApplicationsTestHelper
  APP_NAMES = ['zohocrm', 'harvest', 'dropbox', 'salesforce', 'salesforce_v2']

  def setup
    super
    # mkt_place = Account.current.features?(:marketplace)
    # Account.current.features.marketplace.destroy if mkt_place
    # Account.current.reload
    Integrations::InstalledApplication.any_instance.stubs(:marketplace_enabled?).returns(false)
    APP_NAMES.each { |app_name| create_application(app_name) }
  end

  def teardown
    super
    Integrations::InstalledApplication.unstub(:marketplace_enabled?)
  end

  def wrap_cname(params)
    { installed_applications: params }
  end

  def test_index
    get :index, controller_params(version: 'private')
    pattern = []
    Account.current.installed_applications.all.each do |app|
      pattern << installed_application_pattern(app)
    end
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_show_installed_app
    app = Account.current.installed_applications.first
    get :show, construct_params(version: 'private', id: app.id)
    assert_response 200
    match_json(installed_application_pattern(app))
  end

  def test_show_missing_app
    get :show, construct_params(version: 'private', id: 10_000_001)
    assert_response 404
    assert_equal ' ', response.body
  end

  def test_app_index_filter
    pattern = []
    pattern << installed_application_pattern(get_installed_app('harvest'))
    get :index, controller_params({ version: 'private', name: 'harvest' }, {})
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_app_index_dropbox
    pattern = []
    pattern << installed_application_pattern(get_installed_app('dropbox'))
    get :index, controller_params({ version: 'private', name: 'dropbox' }, {})
    assert_response 200
    match_json(pattern.ordered!)
  end

  def test_app_index_filter_with_multipe_names
    pattern = []
    pattern << installed_application_pattern(get_installed_app('harvest'))
    pattern << installed_application_pattern(get_installed_app('zohocrm'))
    get :index, controller_params({ version: 'private', name: 'harvest,zohocrm' }, {})
    assert_response 200
    match_json(pattern.sort_by!{ |o| [o[:id]]})
  end

  def test_app_index_with_invalid_filter
    get :index, controller_params(version: 'private', abc: 'harvest')
    match_json([bad_request_error_pattern('abc', :invalid_field, 
      code: :invalid_field, description: 'Validation failed')])
    assert_response 400
  end

  def test_salesforce_contact_fetch
    app_id = get_installed_app('salesforce').id
    response = '{"totalSize":1,"done":true,"records":[{"attributes":{"type":
    "Contact","url":"/services/data/v20.0/sobjects/Contact/0037F00000NLydYQAT"},
    "Name":"Tom cruse","Id":"0037F00000NLydYQAT","IsDeleted":false,
    "MasterRecordId":null,"AccountId":"0017F00000QVHSYQA5","LastName":"cruse",
    "FirstName":"Tom","Salutation":"Mr.","OtherStreet":null,"OtherCity":null}]}'
    response_mock = get_response_mock(response, 200)
    IntegrationServices::Services::Salesforce::SalesforceContactResource.
      any_instance.stubs(:http_get).returns(response_mock)
    param = construct_params(get_request_payload(app_id, 
      'fetch_user_selected_fields','contact','tom@localhost.freshdesk-dev.com'))
    post :fetch, param
    assert_response 200
    assert response_mock.verify
    match_json JSON.parse(response)
    IntegrationServices::Services::Salesforce::SalesforceContactResource.any_instance.unstub
  end

  def test_salesforce_account_fetch
    app_id = get_installed_app('salesforce').id
    response = '{"totalSize":1,"done":true,"records":[{"attributes":{"type":
    "Account","url":"/services/data/v20.0/sobjects/Account/0017F00000QVHSYQA5"},
    "Name":"google","Id":"0017F00000QVHSYQA5","IsDeleted":false,
    "MasterRecordId":null,"Type":null,"ParentId":null,"BillingStreet":null,
    "BillingCity":null,"BillingState":null,"BillingPostalCode":null}]}'
    response_mock = get_response_mock(response, 200)
    IntegrationServices::Services::Salesforce::SalesforceAccountResource.
      any_instance.stubs(:http_get).returns(response_mock)
    param = construct_params(get_request_payload(app_id, 
      'fetch_user_selected_fields','account',{email: "tom@localhost.freshdesk-dev.com"}))
    post :fetch, param
    assert_response 200
    assert response_mock.verify
    match_json JSON.parse(response)
    IntegrationServices::Services::Salesforce::SalesforceAccountResource.any_instance.unstub
  end

  def test_salesforce_lead_fetch
    app_id = get_installed_app('salesforce').id
    response = '{"totalSize":1,"done":true,"records":[{"attributes":
    {"type":"Lead","url":"/services/data/v20.0/sobjects/Lead/00Q7F0000065UvIUAU"},
    "Name":"asasas","Id":"00Q7F0000065UvIUAU","IsDeleted":false,
    "MasterRecordId":null,"LastName":"asasas","FirstName":null,
    "Salutation":null,"Title":null,"Company":"google","Street":null}]}'
    response_mock = get_response_mock(response, 200)
    IntegrationServices::Services::Salesforce::SalesforceLeadResource.
      any_instance.stubs(:http_get).returns(response_mock)
    param = construct_params(get_request_payload(app_id, 
      'fetch_user_selected_fields','lead','tom@localhost.freshdesk-dev.com'))
    post :fetch, param
    assert_response 200
    assert response_mock.verify
    match_json JSON.parse(response)
    IntegrationServices::Services::Salesforce::SalesforceLeadResource.any_instance.unstub
  end

  def test_salesforce_opportunity_fetch
    app_id = get_installed_app('salesforce').id
    response = '{"totalSize":1,"done":true,"records":[{"attributes":{"type":
    "Account","url":"/services/data/v20.0/sobjects/Account/0017F00000QVHSYQA5"},
    "Name":"google","Id":"0017F00000QVHSYQA5","IsDeleted":false,
    "MasterRecordId":null,"Type":null,"ParentId":null,"BillingStreet":null,
    "BillingCity":null,"BillingState":null,"BillingPostalCode":null }]}'
    response_mock = get_response_mock(response, 200)
    IntegrationServices::Services::Salesforce::SalesforceOpportunityResource.
      any_instance.stubs(:http_get).returns(response_mock)
    payload = get_request_payload(app_id, 'fetch_user_selected_fields',
      'opportunity', { account_id: "0017F00000QVHSYQA5"})
    payload[:payload][:ticket_id] = Account.current.tickets.last.id
    post :fetch, construct_params(payload)
    assert_response 200
    assert response_mock.verify
    data = JSON.parse(response)
    data["records"][0]["link_status"] = false
    match_json data
    IntegrationServices::Services::Salesforce::SalesforceOpportunityResource.any_instance.unstub
  end

  def test_fetch_for_404_on_invalid_installed_application_id
    invalid_id = Integrations::InstalledApplication.maximum(:id) + 1000
    param = construct_params(get_request_payload(invalid_id, 
      'fetch_user_selected_fields','contact','tom@localhost.freshdesk-dev.com'))
    post :fetch, param
    assert_response 404
  end

  def test_fetch_for_403_on_unsupported_apps
    app_id = get_installed_app('zohocrm').id
    param = construct_params(get_request_payload(app_id, 
      'fetch_user_selected_fields','contact','tom@localhost.freshdesk-dev.com'))
    post :fetch, param
    assert_response 403
  end

  def test_contact_fetch_on_salesforce_v2
    app_id = get_installed_app('salesforce_v2').id
    response = '{"totalSize":1,"done":true,"records":[{"attributes":{"type":
    "Contact","url":"/services/data/v20.0/sobjects/Contact/0037F00000NLydYQAT"},
    "Name":"Tom cruse","Id":"0037F00000NLydYQAT","IsDeleted":false,
    "MasterRecordId":null,"AccountId":"0017F00000QVHSYQA5","LastName":"cruse",
    "FirstName":"Tom","Salutation":"Mr.","OtherStreet":null,"OtherCity":null}]}'
    response_mock = get_response_mock(response, 200)
    IntegrationServices::Services::Salesforce::SalesforceContactResource.
      any_instance.stubs(:http_get).returns(response_mock)
    param = construct_params(get_request_payload(app_id, 
      'fetch_user_selected_fields','contact','tom@localhost.freshdesk-dev.com'))
    post :fetch, param
    assert_response 200
    assert response_mock.verify
    match_json JSON.parse(response)
    IntegrationServices::Services::Salesforce::SalesforceContactResource.any_instance.unstub
  end
end
