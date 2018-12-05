require_relative '../../test_helper'
class Ember::InstalledApplicationsControllerTest < ActionController::TestCase
  include InstalledApplicationsTestHelper
  APP_NAMES = ['zohocrm', 'harvest', 'dropbox', 'salesforce', 'salesforce_v2', 'freshsales']

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

  def test_freshsales_autocomplete_results
    app_id = get_installed_app('freshsales').id
    response = "[{\"id\":\"2009495244\", \"type\": \"contact\",
                                         \"name\": \"testtest\", \"email\": \"test@test.com\"}]"
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    IntegrationServices::Services::Freshsales::FreshsalesCommonResource.
      any_instance.stubs(:http_get).returns(response_mock)
    param = construct_params({ version: 'private', id: app_id, event: 'fetch_autocomplete_results',
                             payload: { url: "/search?per_page=5&include=lead,contact,sales_account,deal&q=test"}})
    post :fetch, param
    assert_response 200
    assert response_mock.verify
    data = JSON.parse(response)
    match_json ({"results" => data})
    IntegrationServices::Services::Freshsales::FreshsalesCommonResource.any_instance.unstub
  end

  def test_freshsales_dropdown_choices
    app_id = get_installed_app('freshsales').id
    response = "{\"users\": [{\"id\":2000067945,\"display_name\":\"Test user\",\"email\":\"test.user@freshworks.com\",\"is_active\":true,\"work_number\":null,\"mobile_number\":null}]}"
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    IntegrationServices::Services::Freshsales::FreshsalesCommonResource.
      any_instance.stubs(:http_get).returns(response_mock)
    param = construct_params({ version: 'private', id: app_id, event: 'fetch_dropdown_choices',
                             payload: { url: "/selector/owners"}})
    post :fetch, param
    assert_response 200
    assert response_mock.verify
    data = JSON.parse(response).values.first
    match_json ({"results" => data})
    IntegrationServices::Services::Freshsales::FreshsalesCommonResource.any_instance.unstub
  end

  def test_freshsales_create_contact
    app_id = get_installed_app('freshsales').id
    response = "{\"contact\":{\"id\": 2009497816, \"first_name\": \"Sample\",\"last_name\": \"Contact\",
                \"display_name\": \"Sample Contact\"}}"
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    IntegrationServices::Services::Freshsales::FreshsalesContactResource.
      any_instance.stubs(:http_post).returns(response_mock)
    param = construct_params({ version: 'private', id: app_id, event: 'create_contact',
                             payload: { entity: { first_name: "Sample", last_name: "Contact"}}})
    post :fetch, param
    assert_response 200
    assert response_mock.verify
    data = JSON.parse(response)
    match_json data
    IntegrationServices::Services::Freshsales::FreshsalesContactResource.any_instance.unstub
  end

  def test_freshsales_create_lead
    app_id = get_installed_app('freshsales').id
    response = "{\"lead\":{\"id\": 2009497816, \"first_name\": \"Sample\",\"last_name\": \"Lead\",
                \"display_name\": \"Sample Lead\"}}"
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    IntegrationServices::Services::Freshsales::FreshsalesLeadResource.
      any_instance.stubs(:http_post).returns(response_mock)
    param = construct_params({ version: 'private', id: app_id, event: 'create_lead',
                             payload: { entity: { first_name: "Sample", last_name: "Lead"}}})
    post :fetch, param
    assert_response 200
    assert response_mock.verify
    data = JSON.parse(response)
    match_json data
    IntegrationServices::Services::Freshsales::FreshsalesLeadResource.any_instance.unstub
  end


  def test_freshsales_fetch_form_fields
    app_id = get_installed_app('freshsales').id
    response = "{\"forms\":[{\"id\":2000022766,\"name\":\"DefaultLeadForm\",
                \"field_class\":\"Lead\",\"fields\":[{\"id\":\"56f639ac\",
                \"name\":\"basic_information\",\"label\":\"Basicinformation\",
                \"fields\":[{\"id\":\"eda895ec\",\"name\":\"first_name\",
                \"label\":\"Firstname\",\"fields\":[],\"form_id\":2000022766,
                \"field_class\":\"Lead\"},{\"id\":\"7e0basd636d\",\"name\":\"email\",
                \"label\":\"Emails\",\"fields\":[],\"form_id\":2000022765,\"visible\":\"false\",
                \"field_class\":\"Contact\",\"field_options\":{\"show_in_import\":true}}]
                ,\"form_id\":2000022766,\"field_class\":\"Lead\"}]},
                {\"id\":2000022765,\"name\":\"DefaultContactForm\",\"field_class\":\"Contact\",
                \"fields\":[{\"id\":\"ead353bc-031b-4012-86b1-cd055f807c99\",\"name\":\"basic_information\",
                \"label\":\"Basicinformation\",\"fields\":[{\"id\":\"7e0b636d\",
                \"name\":\"first_name\",\"label\":\"Firstname\",\"fields\":[],\"form_id\":2000022765,
                \"field_class\":\"Contact\",\"field_options\":{\"show_in_import\":true}},
                {\"id\":\"7e0basd636d\", \"name\":\"email\",\"label\":\"Emails\",\"fields\":[],
                \"form_id\":2000022765,\"field_class\":\"Contact\",\"visible\":\"false\",
                \"field_options\":{\"show_in_import\":true}},{\"id\":\"c94aae94-7424-498f-863c-02bb7350724e\",
                \"name\":\"system_information\",\"label\":\"Systeminformation\",\"fields\":[{\"id\":\"7aee054f\",
                \"name\":\"last_contacted\",\"label\":\"Lastcontactedtime\",\"fields\":[],
                \"form_id\":2000022765,\"field_class\":\"Contact\"}],\"form_id\":2000022765,
                \"field_class\":\"Contact\"}],\"form_id\":2000022765,\"field_class\":\"Contact\"}]}]}"
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    IntegrationServices::Services::Freshsales::FreshsalesCommonResource.
      any_instance.stubs(:http_get).returns(response_mock)
    param = construct_params({ version: 'private', id: app_id, event: 'fetch_form_fields'})
    post :fetch, param
    assert_response 200
    assert response_mock.verify
    data = form_fields_result
    match_json data
    IntegrationServices::Services::Freshsales::FreshsalesCommonResource.any_instance.unstub
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
    response = '[{"Name":"1g10 FDsquad2title", "Id":"0037F000014SHRrQAO", "IsDeleted":false,
    "AccountId":"0017F00001KlKN0QAN", "LastName":"FDsquad2title", "FirstName":"1g10",
    "Salutation":"Mr."}]'
    configured_fields = ["Name", "Id", "IsDeleted", "MasterRecordId", "AccountId", "LastName", "FirstName", "Salutation", "OtherStreet", "OtherCity", "Id"]
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    IntegrationServices::Services::CloudElements::Hub::Crm::ContactResource.
      any_instance.stubs(:http_get).returns(response_mock)
    param = construct_params(get_request_payload(app_id, 
      'fetch_user_selected_fields','contact','4.g10squad1@gmail.com'))
    post :fetch, param
    assert_response 200
    assert response_mock.verify
    match_json(salesforce_v2_response_pattern(response, configured_fields, 'Contact'))
  ensure
    IntegrationServices::Services::CloudElements::Hub::Crm::ContactResource.any_instance.unstub
  end

  def test_account_fetch_on_salesforce_v2
    app_id = get_installed_app('salesforce_v2').id
    response = '[{"LastModifiedDate":"2018-11-14T13:30:40.000+0000",
    "IsDeleted":false,"LastViewedDate":"2018-11-14T13:31:30.000+0000",
    "LastReferencedDate":"2018-11-14T13:31:30.000+0000",
    "Name":"Abernathy, Swift and Huels","SystemModstamp":"2018-11-14T13:30:40.000+0000",
    "BillingAddress":{"street":"salesforce billing street to notes"},
    "CleanStatus":"Pending","CreatedById":"0057F000002ILo1QAG",
    "OwnerId":"0057F000002ILo1QAG","BillingStreet":"salesforce billing street to notes",
    "CreatedDate":"2018-11-07T10:45:15.000+0000",
    "PhotoUrl":"/services/images/photo/0017F00001KlKN0QAN",
    "Id":"0017F00001KlKN0QAN","LastModifiedById":"0057F000002ILo1QAG"}]'
    configured_fields = ["Name", "Id", "IsDeleted", "MasterRecordId", "Type", "ParentId", "BillingStreet", "BillingCity", "BillingState", "BillingPostalCode", "Id"]
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    acc_response = '[{"LastModifiedDate":"2018-11-14T13:21:58.000+0000",
    "IsDeleted":false,"AccountId":"0017F00001KlKN0QAN",
    "Email":"4.g10squad1@gmail.com","IsEmailBounced":false,
    "FDCONTACTID__c":"992819","AssistantName":"titile name",
    "FirstName":"1g10","LastViewedDate":"2018-11-19T12:37:15.000+0000",
    "LastReferencedDate":"2018-11-19T12:37:15.000+0000",
    "MailingAddress":{"street":"FD street to update in freshdesk application"},
    "Salutation":"Mr.","Name":"1g10 FDsquad2title",
    "SystemModstamp":"2018-11-14T13:21:58.000+0000","CleanStatus":"Pending",
    "CreatedById":"0057F000002ILo1QAG","OwnerId":"0057F000002ILo1QAG",
    "CreatedDate":"2018-11-14T13:15:02.000+0000",
    "PhotoUrl":"/services/images/photo/0037F000014SHRrQAO",
    "Id":"0037F000014SHRrQAO","LastName":"FDsquad2title",
    "LastModifiedById":"0057F000002ILo1QAG",
    "MailingStreet":"FD street to update in freshdesk application"}]'
    acc_response_mock = Minitest::Mock.new
    acc_response_mock.expect :body, acc_response
    acc_response_mock.expect :status, 200
    IntegrationServices::Services::CloudElements::Hub::Crm::ContactResource.
      any_instance.stubs(:http_get).returns(acc_response_mock)
    IntegrationServices::Services::CloudElements::Hub::Crm::AccountResource.
      any_instance.stubs(:http_get).returns(response_mock)
    param = construct_params(get_request_payload(app_id, 
      'fetch_user_selected_fields','account',{email: "4.g10squad1@gmail.com"}))
    post :fetch, param
    assert_response 200
    assert response_mock.verify
    match_json(salesforce_v2_response_pattern(response, configured_fields, 'Account'))
  ensure
    IntegrationServices::Services::CloudElements::Hub::Crm::AccountResource.any_instance.unstub
    IntegrationServices::Services::CloudElements::Hub::Crm::ContactResource.any_instance.unstub
  end
end
