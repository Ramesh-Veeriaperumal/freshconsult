require_relative '../../test_helper'
class Ember::InstalledApplicationsControllerTest < ActionController::TestCase
  include InstalledApplicationsTestHelper
  APP_NAMES = ['zohocrm', 'harvest', 'dropbox', 'salesforce', 'salesforce_v2', 'freshsales', 'shopify', 'freshworkscrm']

  def setup
    super
    # mkt_place = Account.current.features?(:marketplace)
    # Account.current.features.marketplace.destroy if mkt_place
    # Account.current.reload
    Integrations::InstalledApplication.any_instance.stubs(:marketplace_enabled?).returns(false)
    delete_all_existing_applications
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
  ensure
    IntegrationServices::Services::Salesforce::SalesforceContactResource.any_instance.unstub(:http_get)
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
  ensure
    IntegrationServices::Services::Salesforce::SalesforceAccountResource.any_instance.unstub(:http_get)
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
  ensure
    IntegrationServices::Services::Salesforce::SalesforceLeadResource.any_instance.unstub(:http_get)
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
  ensure
    IntegrationServices::Services::Salesforce::SalesforceOpportunityResource.any_instance.unstub(:http_get)
  end

  def test_freshsales_autocomplete_results
    app_id = get_installed_app('freshsales').id
    response = "[{\"id\":\"2009495244\", \"type\": \"contact\",
                                         \"name\": \"testtest\", \"email\": \"test@test.com\", \"_id\":\"2009495244\"}]"
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
  ensure
    IntegrationServices::Services::Freshsales::FreshsalesCommonResource.any_instance.unstub(:http_get)
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
  ensure
    IntegrationServices::Services::Freshsales::FreshsalesCommonResource.any_instance.unstub(:http_get)
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
  ensure
    IntegrationServices::Services::Freshsales::FreshsalesContactResource.any_instance.unstub(:http_get)
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
  ensure
    IntegrationServices::Services::Freshsales::FreshsalesLeadResource.any_instance.unstub(:http_post)
  end


  def test_freshsales_fetch_form_fields
    app_id = get_installed_app('freshsales').id
    response = "{\"forms\":[{\"id\":2000022766,\"name\":\"DefaultLeadForm\",
                \"field_class\":\"Lead\",\"fields\":[{\"id\":\"56f639ac\",
                \"name\":\"basic_information\",\"label\":\"Basicinformation\",
                \"fields\":[{\"id\":\"eda895ec\",\"name\":\"first_name\",
                \"label\":\"Firstname\",\"fields\":[],\"form_id\":2000022766,
                \"field_class\":\"Lead\"},{\"id\":\"7e0basd636d\",\"name\":\"emails\",\"type\":\"email\",
                \"label\":\"Emails\",\"fields\":[],\"form_id\":2000022765,\"visible\":\"true\",
                \"field_class\":\"Contact\",\"field_options\":{\"show_in_import\":true}}]
                ,\"form_id\":2000022766,\"field_class\":\"Lead\"}]},
                {\"id\":2000022765,\"name\":\"DefaultContactForm\",\"field_class\":\"Contact\",
                \"fields\":[{\"id\":\"ead353bc-031b-4012-86b1-cd055f807c99\",\"name\":\"basic_information\",
                \"label\":\"Basicinformation\",\"fields\":[{\"id\":\"7e0b636d\",
                \"name\":\"first_name\",\"label\":\"Firstname\",\"fields\":[],\"form_id\":2000022765,
                \"field_class\":\"Contact\",\"field_options\":{\"show_in_import\":true}},
                {\"id\":\"7e0basd636d\", \"name\":\"emails\",\"type\":\"email\",\"label\":\"Emails\",\"fields\":[],
                \"form_id\":2000022765,\"field_class\":\"Contact\",\"visible\":\"true\",
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
  ensure
    IntegrationServices::Services::Freshsales::FreshsalesCommonResource.any_instance.unstub(:http_get)
  end

  def test_freshsales_fetch_form_fields_with_nested_emails
    app_id = get_installed_app('freshsales').id
    response = fetch_nested_emails_response
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    IntegrationServices::Services::Freshsales::FreshsalesCommonResource
      .any_instance.stubs(:http_get).returns(response_mock)
    param = construct_params(version: 'private', id: app_id, event: 'fetch_form_fields')
    post :fetch, param
    assert_response 200
    assert response_mock.verify
    data = nested_emails_form_fields_result
    match_json data
  ensure
    IntegrationServices::Services::Freshsales::FreshsalesCommonResource.any_instance.unstub(:http_get)
  end

  def test_install_freshworkscrm_app
    freshworkscrm_application_id = Integrations::Application.where(name: 'freshworkscrm').first.id
    Account.current.installed_applications.where(application_id: freshworkscrm_application_id).first.delete
    post :create, construct_params(version: 'private', name: 'freshworkscrm', configs: { domain: 'test', auth_token: 'v_GNcz8s2BmhzOVsp4Oe_w', ghostvalue: '.myfreshworks.com' })
    assert_equal freshworkscrm_application_id, JSON.parse(response.body)['application_id']
    assert_response 200
  end

  def test_freshworkscrm_autocomplete_results
    app_id = get_installed_app('freshworkscrm').id
    response = "[{\"id\":\"2009495244\", \"type\": \"contact\", \"name\": \"testtest\", \"email\": \"test@test.com\", \"_id\":\"2009495244\"}]"
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmCommonResource
      .any_instance.stubs(:http_get).returns(response_mock)
    param = construct_params(version: 'private', id: app_id, event: 'fetch_autocomplete_results',
                             payload: { url: '/search?per_page=5&include=contact,sales_account,deal&q=test' })
    post :fetch, param
    assert_response 200
    assert response_mock.verify
    data = JSON.parse(response)
    match_json ({ 'results' => data })
  ensure
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmCommonResource.any_instance.unstub(:http_get)
  end

  def test_freshworkscrm_dropdown_choices
    app_id = get_installed_app('freshworkscrm').id
    response = "{\"users\": [{\"id\":2000067945,\"display_name\":\"Test user\",\"email\":\"test.user@freshworks.com\",\"is_active\":true,\"work_number\":null,\"mobile_number\":null}]}"
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmCommonResource
      .any_instance.stubs(:http_get).returns(response_mock)
    param = construct_params(version: 'private', id: app_id, event: 'fetch_dropdown_choices', payload: { url: '/selector/owners' })
    post :fetch, param
    assert_response 200
    assert response_mock.verify
    data = JSON.parse(response).values.first
    match_json ({ 'results' => data })
  ensure
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmCommonResource.any_instance.unstub(:http_get)
  end

  def test_freshworkscrm_create_contact
    app_id = get_installed_app('freshworkscrm').id
    response = "{\"contact\":{\"id\": 2009497816, \"first_name\": \"Sample\",\"last_name\": \"Contact\", \"display_name\": \"Sample Contact\"}}"
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmContactResource
      .any_instance.stubs(:http_post).returns(response_mock)
    param = construct_params(version: 'private', id: app_id, event: 'create_contact',
                             payload: { entity: { first_name: 'Sample', last_name: 'Contact' } })
    post :fetch, param
    assert_response 200
    assert response_mock.verify
    data = JSON.parse(response)
    match_json data
  ensure
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmContactResource.any_instance.unstub(:http_get)
  end

  def test_freshworkscrm_create_contact_returns_exception
    app_id = get_installed_app('freshworkscrm').id
    response = "{\"contact\":{\"id\": 2009497816, \"first_name\": \"Sample\",\"last_name\": \"Contact\", \"display_name\": \"Sample Contact\"}}"
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 400
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmContactResource
      .any_instance.stubs(:http_post).returns(response_mock)
    param = construct_params(version: 'private', id: app_id, event: 'create_contact',
                             payload: { entity: { first_name: 'Sample', last_name: 'Contact' } })
    post :fetch, param
    assert_response 502
  ensure
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmContactResource.any_instance.unstub(:http_get)
  end

  def test_freshworkscrm_fetch_form_fields
    app_id = get_installed_app('freshworkscrm').id
    response = "{\"forms\":[{\"id\":2000022765,\"name\":\"DefaultContactForm\",\"field_class\":\"Contact\",
                \"fields\":[{\"id\":\"ead353bc-031b-4012-86b1-cd055f807c99\",\"name\":\"basic_information\",
                \"label\":\"Basicinformation\",\"fields\":[{\"id\":\"7e0b636d\",
                \"name\":\"first_name\",\"label\":\"Firstname\",\"fields\":[],\"form_id\":2000022765,
                \"field_class\":\"Contact\",\"field_options\":{\"show_in_import\":true}},
                {\"id\":\"7e0basd636d\", \"name\":\"emails\",\"type\":\"email\",\"label\":\"Emails\",\"fields\":[],
                \"form_id\":2000022765,\"field_class\":\"Contact\",\"visible\":\"true\",
                \"field_options\":{\"show_in_import\":true}},{\"id\":\"c94aae94-7424-498f-863c-02bb7350724e\",
                \"name\":\"system_information\",\"label\":\"Systeminformation\",\"fields\":[{\"id\":\"7aee054f\",
                \"name\":\"last_contacted\",\"label\":\"Lastcontactedtime\",\"fields\":[],
                \"form_id\":2000022765,\"field_class\":\"Contact\"}],\"form_id\":2000022765,
                \"field_class\":\"Contact\"}],\"form_id\":2000022765,\"field_class\":\"Contact\"}]}]}"
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmCommonResource
      .any_instance.stubs(:http_get).returns(response_mock)
    param = construct_params(version: 'private', id: app_id, event: 'fetch_form_fields')
    post :fetch, param
    assert_response 200
    assert response_mock.verify
    data = form_fields_result_for_freshworkscrm
    match_json data
  ensure
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmCommonResource.any_instance.unstub(:http_get)
  end

  def test_freshworkscrm_fetch_contacts
    app_id = get_installed_app('freshworkscrm').id
    response = "{\"contact_status\":[{\"id\":9000047558,\"name\":\"Qualified Lead\",\"position\":1}], \"contact\":{\"id\":15001322339,\"first_name\":\"Matt\",\"last_name\":\"Rogers\",\"display_name\":\"Matt Rogers\",\"avatar\":null,\"job_title\":null,\"city\":null,\"state\":null,\"zipcode\":null,\"country\":null,\"email\":\"matt.rogers@freshdesk.com\",\"emails\":[{\"id\":15001148901,\"value\":\"matt.rogers@freshdesk.com\",\"is_primary\":true,\"label\":null,\"_destroy\":false}],\"time_zone\":null,\"work_number\":null,\"mobile_number\":\"1000\",\"address\":null,\"last_seen\":null,\"lead_score\":90,\"last_contacted\":null,\"open_deals_amount\":\"100.0\",\"won_deals_amount\":\"0.0\",\"links\":{\"conversations\":\"/contacts/15001322339/conversations/all?include=email_conversation_recipients%2Ctargetable%2Cphone_number%2Cphone_caller%2Cnote%2Cuser\u0026per_page=3\",\"timeline_feeds\":\"/contacts/15001322339/timeline_feeds\",\"document_associations\":\"/contacts/15001322339/document_associations\",\"notes\":\"/contacts/15001322339/notes?include=creater\",\"tasks\":\"/contacts/15001322339/tasks?include=creater,owner,updater,targetable,users,task_type\",\"reminders\":\"/contacts/15001322339/reminders?include=creater,owner,updater,targetable\",\"appointments\":\"/contacts/15001322339/appointments?include=creater,owner,updater,targetable,appointment_attendees\",\"duplicates\":\"/contacts/15001322339/duplicates\",\"connections\":\"/contacts/15001322339/connections\"},\"last_contacted_sales_activity_mode\":null,\"custom_field\":{},\"created_at\":\"2020-09-03T19:33:30+05:30\",\"updated_at\":\"2020-09-03T19:33:30+05:30\",\"keyword\":null,\"medium\":null,\"last_contacted_mode\":null,\"recent_note\":null,\"won_deals_count\":0,\"last_contacted_via_sales_activity\":null,\"completed_sales_sequences\":null,\"active_sales_sequences\":null,\"web_form_ids\":null,\"open_deals_count\":1,\"last_assigned_at\":\"2020-09-03T19:33:31+05:30\",\"tags\":[],\"facebook\":null,\"twitter\":null,\"linkedin\":null,\"is_deleted\":false,\"team_user_ids\":null,\"subscription_status\":0,\"customer_fit\":0,\"has_duplicates\":true,\"duplicates_searched_today\":true,\"has_connections\":true,\"connections_searched_today\":true,\"phone_numbers\":[], \"contact_status_id\":9000047558, \"custom_field\":{\"time_zone\":\"CST\"}} }"
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    filter_response = "{\"contacts\":[{\"partial\":true,\"id\":15001322339,\"job_title\":null,\"lead_score\":90,\"email\":\"matt.rogers@freshdesk.com\",\"emails\":[{\"id\":15001148901,\"value\":\"matt.rogers@freshdesk.com\",\"is_primary\":true,\"label\":null,\"_destroy\":false}],\"work_number\":null,\"mobile_number\":\"1000\",\"open_deals_amount\":\"100.0\",\"won_deals_amount\":\"0.0\",\"display_name\":\"Matt Rogers\",\"avatar\":null,\"last_contacted_mode\":null,\"last_contacted\":null,\"last_contacted_via_sales_activity\":null,\"first_name\":\"Matt\",\"last_name\":\"Rogers\",\"city\":null,\"country\":null,\"created_at\":\"2020-09-03T19:33:30+05:30\",\"updated_at\":\"2020-09-03T19:33:30+05:30\",\"recent_note\":null,\"last_contacted_sales_activity_mode\":null,\"web_form_ids\":null,\"last_assigned_at\":\"2020-09-03T19:33:31+05:30\",\"external_id\":null,\"facebook\":null,\"twitter\":null,\"linkedin\":null}],\"meta\":{\"total\":1}}"
    filter_response_mock = Minitest::Mock.new
    filter_response_mock.expect :body, filter_response
    filter_response_mock.expect :status, 200
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmContactResource.any_instance.stubs(:http_get).returns(response_mock)
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmContactResource.any_instance.stubs(:http_post).returns(filter_response_mock)
    param = construct_params(version: 'private', id: app_id, event: 'fetch_user_selected_fields', payload: { type: 'contact', value: { email: 'matt.rogers@freshdesk.com' } })
    post :fetch, param
    assert_response 200
    response_hash = JSON.parse response
    assert_equal response_hash['contact']['email'], 'matt.rogers@freshdesk.com'
  ensure
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmContactResource.any_instance.unstub(:http_get)
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmContactResource.any_instance.unstub(:http_post)
  end

  def test_freshworkscrm_fetch_contacts_with_no_filter_results
    app_id = get_installed_app('freshworkscrm').id
    filter_response = '{}'
    filter_response_mock = Minitest::Mock.new
    filter_response_mock.expect :body, filter_response
    filter_response_mock.expect :status, 200
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmContactResource.any_instance.stubs(:http_post).returns(filter_response_mock)
    param = construct_params(version: 'private', id: app_id, event: 'fetch_user_selected_fields', payload: { type: 'contact', value: { email: 'matt.rogers@freshdesk.com' } })
    post :fetch, param
    assert_response 200
  ensure
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmContactResource.any_instance.unstub(:http_get)
  end

  def test_freshworkscrm_fetch_contacts_with_exception
    app_id = get_installed_app('freshworkscrm').id
    response = "{\"contact\":{\"id\":15001322339,\"first_name\":\"Matt\",\"last_name\":\"Rogers\",\"display_name\":\"Matt Rogers\",\"avatar\":null,\"job_title\":null,\"city\":null,\"state\":null,\"zipcode\":null,\"country\":null,\"email\":\"matt.rogers@freshdesk.com\",\"emails\":[{\"id\":15001148901,\"value\":\"matt.rogers@freshdesk.com\",\"is_primary\":true,\"label\":null,\"_destroy\":false}],\"time_zone\":null,\"work_number\":null,\"mobile_number\":\"1000\",\"address\":null,\"last_seen\":null,\"lead_score\":90,\"last_contacted\":null,\"open_deals_amount\":\"100.0\",\"won_deals_amount\":\"0.0\",\"links\":{\"conversations\":\"/contacts/15001322339/conversations/all?include=email_conversation_recipients%2Ctargetable%2Cphone_number%2Cphone_caller%2Cnote%2Cuser\u0026per_page=3\",\"timeline_feeds\":\"/contacts/15001322339/timeline_feeds\",\"document_associations\":\"/contacts/15001322339/document_associations\",\"notes\":\"/contacts/15001322339/notes?include=creater\",\"tasks\":\"/contacts/15001322339/tasks?include=creater,owner,updater,targetable,users,task_type\",\"reminders\":\"/contacts/15001322339/reminders?include=creater,owner,updater,targetable\",\"appointments\":\"/contacts/15001322339/appointments?include=creater,owner,updater,targetable,appointment_attendees\",\"duplicates\":\"/contacts/15001322339/duplicates\",\"connections\":\"/contacts/15001322339/connections\"},\"last_contacted_sales_activity_mode\":null,\"custom_field\":{},\"created_at\":\"2020-09-03T19:33:30+05:30\",\"updated_at\":\"2020-09-03T19:33:30+05:30\",\"keyword\":null,\"medium\":null,\"last_contacted_mode\":null,\"recent_note\":null,\"won_deals_count\":0,\"last_contacted_via_sales_activity\":null,\"completed_sales_sequences\":null,\"active_sales_sequences\":null,\"web_form_ids\":null,\"open_deals_count\":1,\"last_assigned_at\":\"2020-09-03T19:33:31+05:30\",\"tags\":[],\"facebook\":null,\"twitter\":null,\"linkedin\":null,\"is_deleted\":false,\"team_user_ids\":null,\"subscription_status\":0,\"customer_fit\":0,\"has_duplicates\":true,\"duplicates_searched_today\":true,\"has_connections\":true,\"connections_searched_today\":true,\"phone_numbers\":[]} }"
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 400
    filter_response = "{\"contacts\":[{\"partial\":true,\"id\":15001322339,\"job_title\":null,\"lead_score\":90,\"email\":\"matt.rogers@freshdesk.com\",\"emails\":[{\"id\":15001148901,\"value\":\"matt.rogers@freshdesk.com\",\"is_primary\":true,\"label\":null,\"_destroy\":false}],\"work_number\":null,\"mobile_number\":\"1000\",\"open_deals_amount\":\"100.0\",\"won_deals_amount\":\"0.0\",\"display_name\":\"Matt Rogers\",\"avatar\":null,\"last_contacted_mode\":null,\"last_contacted\":null,\"last_contacted_via_sales_activity\":null,\"first_name\":\"Matt\",\"last_name\":\"Rogers\",\"city\":null,\"country\":null,\"created_at\":\"2020-09-03T19:33:30+05:30\",\"updated_at\":\"2020-09-03T19:33:30+05:30\",\"recent_note\":null,\"last_contacted_sales_activity_mode\":null,\"web_form_ids\":null,\"last_assigned_at\":\"2020-09-03T19:33:31+05:30\",\"external_id\":null,\"facebook\":null,\"twitter\":null,\"linkedin\":null}],\"meta\":{\"total\":1}}"
    filter_response_mock = Minitest::Mock.new
    filter_response_mock.expect :body, filter_response
    filter_response_mock.expect :status, 200
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmContactResource.any_instance.stubs(:http_get).returns(response_mock)
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmContactResource.any_instance.stubs(:http_post).returns(filter_response_mock)
    param = construct_params(version: 'private', id: app_id, event: 'fetch_user_selected_fields', payload: { type: 'contact', value: { email: 'matt.rogers@freshdesk.com' } })
    post :fetch, param
    assert_response 502
  ensure
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmContactResource.any_instance.unstub(:http_get)
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmContactResource.any_instance.unstub(:http_post)
  end

  def test_freshworkscrm_fetch_accounts_from_email
    app_id = get_installed_app('freshworkscrm').id
    response = "{\"sales_account\":{\"id\":15000767664,\"name\":\"Flipkart\",\"address\":null,\"city\":null,\"state\":null,\"zipcode\":null,\"country\":null,\"number_of_employees\":null,\"annual_revenue\":null,\"website\":null,\"owner_id\":15000014169,\"phone\":null,\"open_deals_amount\":\"100.0\",\"open_deals_count\":1,\"won_deals_amount\":\"0.0\",\"won_deals_count\":0,\"last_contacted\":null,\"last_contacted_mode\":null,\"facebook\":null,\"twitter\":null,\"linkedin\":null,\"links\":{\"conversations\":\"/sales_accounts/15000767664/conversations/all?include=email_conversation_recipients%2Ctargetable%2Cphone_number%2Cphone_caller%2Cnote%2Cuser\u0026per_page=3\",\"document_associations\":\"/sales_accounts/15000767664/document_associations\",\"notes\":\"/sales_accounts/15000767664/notes?include=creater\",\"tasks\":\"/sales_accounts/15000767664/tasks?include=creater,owner,updater,targetable,users,task_type\",\"appointments\":\"/sales_accounts/15000767664/appointments?include=creater,owner,updater,targetable,appointment_attendees\"},\"custom_field\":{},\"created_at\":\"2020-09-03T19:33:04+05:30\",\"updated_at\":\"2020-09-03T19:33:04+05:30\",\"avatar\":null,\"parent_sales_account_id\":null,\"recent_note\":null,\"last_contacted_via_sales_activity\":null,\"last_contacted_sales_activity_mode\":null,\"completed_sales_sequences\":null,\"active_sales_sequences\":null,\"last_assigned_at\":\"2020-09-03T19:33:05+05:30\",\"tags\":[],\"is_deleted\":false,\"team_user_ids\":null,\"has_connections\":true}}"
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    filter_response = "{\"sales_accounts\":[{\"partial\":true,\"id\":15000767664,\"name\":\"Flipkart\",\"avatar\":null,\"website\":null,\"open_deals_amount\":\"100.0\",\"open_deals_count\":1,\"won_deals_amount\":\"0.0\",\"won_deals_count\":0,\"last_contacted\":null}],\"contacts\":[{\"partial\":true,\"id\":15001322339,\"job_title\":null,\"lead_score\":90,\"email\":\"matt.rogers@freshdesk.com\",\"emails\":[{\"id\":15001148901,\"value\":\"matt.rogers@freshdesk.com\",\"is_primary\":true,\"label\":null,\"_destroy\":false}],\"work_number\":null,\"mobile_number\":\"1000\",\"open_deals_amount\":\"100.0\",\"won_deals_amount\":\"0.0\",\"display_name\":\"Matt Rogers\",\"avatar\":null,\"last_contacted_mode\":null,\"last_contacted\":null,\"last_contacted_via_sales_activity\":null,\"first_name\":\"Matt\",\"last_name\":\"Rogers\",\"city\":null,\"country\":null,\"created_at\":\"2020-09-03T19:33:30+05:30\",\"updated_at\":\"2020-09-03T19:33:30+05:30\",\"recent_note\":null,\"last_contacted_sales_activity_mode\":null,\"web_form_ids\":null,\"last_assigned_at\":\"2020-09-03T19:33:31+05:30\",\"external_id\":null,\"facebook\":null,\"twitter\":null,\"linkedin\":null,\"sales_account_id\":15000767664}],\"meta\":{\"total\":1}}"
    filter_response_mock = Minitest::Mock.new
    filter_response_mock.expect :body, filter_response
    filter_response_mock.expect :status, 200
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmAccountResource.any_instance.stubs(:http_get).returns(response_mock)
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmAccountResource.any_instance.stubs(:http_post).returns(filter_response_mock)
    param = construct_params(version: 'private', id: app_id, event: 'fetch_user_selected_fields', payload: { type: 'account', value: { email: 'matt.rogers@freshdesk.com' } })
    post :fetch, param
    assert_response 200
    response_hash = JSON.parse response
    assert_equal response_hash['sales_account']['id'], 15_000_767_664
  ensure
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmAccountResource.any_instance.unstub(:http_get)
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmAccountResource.any_instance.unstub(:http_post)
  end

  def test_freshworkscrm_fetch_accounts_from_company
    app_id = get_installed_app('freshworkscrm').id
    response = "{\"sales_account\":{\"id\":15000767664,\"name\":\"Flipkart\",\"address\":null,\"city\":null,\"state\":null,\"zipcode\":null,\"country\":null,\"number_of_employees\":null,\"annual_revenue\":null,\"website\":null,\"owner_id\":15000014169,\"phone\":null,\"open_deals_amount\":\"100.0\",\"open_deals_count\":1,\"won_deals_amount\":\"0.0\",\"won_deals_count\":0,\"last_contacted\":null,\"last_contacted_mode\":null,\"facebook\":null,\"twitter\":null,\"linkedin\":null,\"links\":{\"conversations\":\"/sales_accounts/15000767664/conversations/all?include=email_conversation_recipients%2Ctargetable%2Cphone_number%2Cphone_caller%2Cnote%2Cuser\u0026per_page=3\",\"document_associations\":\"/sales_accounts/15000767664/document_associations\",\"notes\":\"/sales_accounts/15000767664/notes?include=creater\",\"tasks\":\"/sales_accounts/15000767664/tasks?include=creater,owner,updater,targetable,users,task_type\",\"appointments\":\"/sales_accounts/15000767664/appointments?include=creater,owner,updater,targetable,appointment_attendees\"},\"custom_field\":{},\"created_at\":\"2020-09-03T19:33:04+05:30\",\"updated_at\":\"2020-09-03T19:33:04+05:30\",\"avatar\":null,\"parent_sales_account_id\":null,\"recent_note\":null,\"last_contacted_via_sales_activity\":null,\"last_contacted_sales_activity_mode\":null,\"completed_sales_sequences\":null,\"active_sales_sequences\":null,\"last_assigned_at\":\"2020-09-03T19:33:05+05:30\",\"tags\":[],\"is_deleted\":false,\"team_user_ids\":null,\"has_connections\":true}}"
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    filter_response = "{\"sales_accounts\":[{\"partial\":true,\"id\":15000767664,\"name\":\"Flipkart\",\"avatar\":null,\"website\":null,\"open_deals_amount\":\"100.0\",\"open_deals_count\":1,\"won_deals_amount\":\"0.0\",\"won_deals_count\":0,\"last_contacted\":null}],\"contacts\":[{\"partial\":true,\"id\":15001322339,\"job_title\":null,\"lead_score\":90,\"email\":\"matt.rogers@freshdesk.com\",\"emails\":[{\"id\":15001148901,\"value\":\"matt.rogers@freshdesk.com\",\"is_primary\":true,\"label\":null,\"_destroy\":false}],\"work_number\":null,\"mobile_number\":\"1000\",\"open_deals_amount\":\"100.0\",\"won_deals_amount\":\"0.0\",\"display_name\":\"Matt Rogers\",\"avatar\":null,\"last_contacted_mode\":null,\"last_contacted\":null,\"last_contacted_via_sales_activity\":null,\"first_name\":\"Matt\",\"last_name\":\"Rogers\",\"city\":null,\"country\":null,\"created_at\":\"2020-09-03T19:33:30+05:30\",\"updated_at\":\"2020-09-03T19:33:30+05:30\",\"recent_note\":null,\"last_contacted_sales_activity_mode\":null,\"web_form_ids\":null,\"last_assigned_at\":\"2020-09-03T19:33:31+05:30\",\"external_id\":null,\"facebook\":null,\"twitter\":null,\"linkedin\":null,\"sales_account_id\":15000767664}],\"meta\":{\"total\":1}}"
    filter_response_mock = Minitest::Mock.new
    filter_response_mock.expect :body, filter_response
    filter_response_mock.expect :status, 200
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmAccountResource.any_instance.stubs(:http_get).returns(response_mock)
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmAccountResource.any_instance.stubs(:http_post).returns(filter_response_mock)
    param = construct_params(version: 'private', id: app_id, event: 'fetch_user_selected_fields', payload: { type: 'account', value: { company: 'Flipkart' } })
    post :fetch, param
    assert_response 200
    response_hash = JSON.parse response
    assert_equal response_hash['sales_account']['name'], 'Flipkart'
  ensure
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmAccountResource.any_instance.unstub(:http_get)
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmAccountResource.any_instance.unstub(:http_post)
  end

  def test_freshworkscrm_fetch_deals
    app_id = get_installed_app('freshworkscrm').id
    response = "{\"deals\":[{\"id\":15000087766,\"name\":\"Electronics Section\",\"amount\":\"100.0\",\"expected_close\":null,\"closed_date\":null,\"stage_updated_time\":\"2020-09-05T23:53:06+05:30\",\"custom_field\":{},\"probability\":100,\"updated_at\":\"2020-09-05T23:53:06+05:30\",\"created_at\":\"2020-09-05T23:53:06+05:30\",\"age\":0,\"collaboration\":{\"id\":\"15000087766\",\"title\":\"Electronics Section\",\"convo_token\":\"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJDb252b0lkIjoiMTUwMDAwODc3NjYiLCJVc2VyVVVJRCI6IjIyMTYzMDM1ODE5NDMwODI2NyIsImV4cCI6MTU5OTMzNzQxN30.itkvIVG-hwD9aFpSxiNbKMPUUpj33fptwUaaSpBcgbE\"},\"last_contacted_via_sales_activity\":null,\"last_contacted_sales_activity_mode\":null,\"base_currency_amount\":\"100.0\",\"expected_deal_value\":\"100.0\",\"rotten_days\":null,\"owner_id\":15000014169,\"creater_id\":15000014169,\"updater_id\":15000014169,\"lead_source_id\":null,\"contact_ids\":[15001322339],\"sales_account_id\":15000767664,\"deal_pipeline_id\":15000011054,\"deal_stage_id\":15000077707,\"deal_type_id\":null,\"deal_reason_id\":null,\"campaign_id\":null,\"deal_payment_status_id\":null,\"deal_product_id\":null,\"territory_id\":null,\"currency_id\":15000010621, \"custom_field\":{\"deal_payment_status_id\":7823728}},{\"id\":15000085358,\"name\":\"Groceries Section\",\"amount\":\"100.0\",\"expected_close\":null,\"closed_date\":null,\"stage_updated_time\":\"2020-09-03T19:34:27+05:30\",\"custom_field\":{\"deal_payment_status_id\":7823728},\"probability\":100,\"updated_at\":\"2020-09-03T19:34:27+05:30\",\"created_at\":\"2020-09-03T19:34:27+05:30\",\"age\":2,\"collaboration\":{\"id\":\"15000085358\",\"title\":\"Groceries Section\",\"convo_token\":\"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJDb252b0lkIjoiMTUwMDAwODUzNTgiLCJVc2VyVVVJRCI6IjIyMTYzMDM1ODE5NDMwODI2NyIsImV4cCI6MTU5OTMzNzQxN30.e3ex7vvvPcb-zU8S4NwLEC9bkqoXXyssxniUcqSr-XE\"},\"last_contacted_via_sales_activity\":null,\"last_contacted_sales_activity_mode\":null,\"base_currency_amount\":\"100.0\",\"expected_deal_value\":\"100.0\",\"rotten_days\":null,\"owner_id\":15000014169,\"creater_id\":15000014169,\"updater_id\":15000014169,\"lead_source_id\":null,\"contact_ids\":[15001322339],\"sales_account_id\":15000767664,\"deal_pipeline_id\":15000011054,\"deal_stage_id\":15000077707,\"deal_type_id\":null,\"deal_reason_id\":null,\"campaign_id\":null,\"deal_payment_status_id\":null,\"deal_product_id\":null,\"territory_id\":null,\"currency_id\":15000010621}],\"users\":[{\"id\":15000014169,\"display_name\":\"Arjun Naduvakkat\",\"email\":\"arjunpn90@gmail.com\",\"is_active\":true,\"work_number\":\"237482482\",\"mobile_number\":null}],\"lead_sources\":[],\"contacts\":[{\"partial\":true,\"id\":15001322339,\"first_name\":\"Matt\",\"last_name\":\"Rogers\",\"display_name\":\"Matt Rogers\",\"avatar\":null,\"email\":\"matt.rogers@freshdesk.com\",\"lead_score\":92,\"last_contacted_sales_activity_mode\":null,\"job_title\":null,\"last_contacted\":null,\"last_contacted_mode\":null,\"last_contacted_via_sales_activity\":null,\"work_number\":null,\"mobile_number\":\"1000\",\"sales_account_id\":15000767664,\"sales_accounts\":[{\"partial\":true,\"id\":15000767664,\"name\":\"Flipkart\",\"avatar\":null,\"website\":null,\"open_deals_amount\":\"200.0\",\"open_deals_count\":2,\"won_deals_amount\":\"0.0\",\"won_deals_count\":0,\"last_contacted\":null,\"is_primary\":true}],\"owner_id\":15000014169}],\"sales_accounts\":[{\"partial\":true,\"id\":15000767664,\"name\":\"Flipkart\",\"avatar\":null,\"website\":null,\"open_deals_amount\":\"200.0\",\"open_deals_count\":2,\"won_deals_amount\":\"0.0\",\"won_deals_count\":0,\"last_contacted\":null}],\"deal_pipelines\":[{\"partial\":true,\"id\":15000011054,\"name\":\"Default Pipeline\",\"position\":1,\"is_default\":true,\"rotting_days\":30}],\"deal_stages\":[{\"partial\":true,\"id\":15000077707,\"name\":\"New\",\"position\":1,\"forecast_type\":\"Open\",\"updated_at\":\"2020-09-03T19:29:57+05:30\",\"deal_pipeline_id\":15000011054,\"choice_type\":5,\"probability\":100}],\"deal_types\":[],\"deal_reasons\":[],\"campaigns\":[],\"deal_payment_statuses\":[],\"deal_products\":[],\"territories\":[],\"currencies\":[{\"partial\":false,\"id\":15000010621,\"is_active\":true,\"currency_code\":\"USD\",\"exchange_rate\":\"1.0\",\"currency_type\":1,\"schedule_info\":null,\"rate_change_ids\":[]}],\"rate_changes\":[],\"sales_account\":{\"id\":15000767664,\"name\":\"Flipkart\",\"address\":null,\"city\":null,\"state\":null,\"zipcode\":null,\"country\":null,\"number_of_employees\":null,\"annual_revenue\":null,\"website\":null,\"owner_id\":15000014169,\"phone\":null,\"open_deals_amount\":\"200.0\",\"open_deals_count\":2,\"won_deals_amount\":\"0.0\",\"won_deals_count\":0,\"last_contacted\":null,\"last_contacted_mode\":null,\"facebook\":null,\"twitter\":null,\"linkedin\":null,\"links\":{\"conversations\":\"/sales_accounts/15000767664/conversations/all?include=email_conversation_recipients%2Ctargetable%2Cphone_number%2Cphone_caller%2Cnote%2Cuser\u0026per_page=3\",\"document_associations\":\"/sales_accounts/15000767664/document_associations\",\"notes\":\"/sales_accounts/15000767664/notes?include=creater\",\"tasks\":\"/sales_accounts/15000767664/tasks?include=creater,owner,updater,targetable,users,task_type\",\"appointments\":\"/sales_accounts/15000767664/appointments?include=creater,owner,updater,targetable,appointment_attendees\"},\"custom_field\":{},\"created_at\":\"2020-09-03T19:33:04+05:30\",\"updated_at\":\"2020-09-03T19:33:04+05:30\",\"avatar\":null,\"parent_sales_account_id\":null,\"recent_note\":null,\"last_contacted_via_sales_activity\":null,\"last_contacted_sales_activity_mode\":null,\"completed_sales_sequences\":null,\"active_sales_sequences\":null,\"last_assigned_at\":\"2020-09-03T19:33:05+05:30\",\"tags\":[],\"is_deleted\":false,\"team_user_ids\":null,\"has_connections\":true,\"deal_ids\":[15000087766,15000085358]}}"
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmDealResource.any_instance.stubs(:http_get).returns(response_mock)
    param = construct_params(version: 'private', id: app_id, event: 'fetch_user_selected_fields', payload: { type: 'deal', value: { account_id: '15000767664', ticket_id: '3' } })
    post :fetch, param
    assert_response 200
    response_hash = JSON.parse response
    assert_equal response_hash['deals'].size, 2
    assert_equal response_hash['deals'][0]['id'], 15_000_087_766
    assert_equal response_hash['deals'][1]['id'], 15_000_085_358
  ensure
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmDealResource.any_instance.unstub(:http_get)
  end

  def test_freshworkscrm_fetch_form_fields_with_nested_emails
    app_id = get_installed_app('freshworkscrm').id
    response = fetch_nested_emails_response_for_freshworkscrm
    response_mock = Minitest::Mock.new
    response_mock.expect :body, response
    response_mock.expect :status, 200
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmCommonResource
      .any_instance.stubs(:http_get).returns(response_mock)
    param = construct_params(version: 'private', id: app_id, event: 'fetch_form_fields')
    post :fetch, param
    assert_response 200
    assert response_mock.verify
    data = nested_emails_form_fields_result_for_freshworkscrm
    match_json data
  ensure
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmCommonResource.any_instance.unstub(:http_get)
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
    IntegrationServices::Services::CloudElements::Hub::Crm::ContactResource.any_instance.unstub(:http_get)
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
    IntegrationServices::Services::CloudElements::Hub::Crm::AccountResource.any_instance.unstub(:http_get)
    IntegrationServices::Services::CloudElements::Hub::Crm::ContactResource.any_instance.unstub(:http_get)
  end

  def test_shopify_refund_full_order
    installed_app = get_installed_app('shopify')
    installed_app.configs[:inputs]['disable_shopify_actions'] = false
    installed_app.save
    order_id = 1025918795834
    line_item_id = nil
    url = 'https://fd-integration-private.myshopify.com'
    order_json = fetch_order.to_json
    calculate_json = fetch_refund_calculate.to_json
    response = fetch_refund_response.to_json

    order_mock = get_response_mock(order_json, 200)
    calculate_mock = get_response_mock(calculate_json, 200)
    response_mock = get_response_mock(response, 201)

    calculate_url = "#{url}/admin/orders/#{order_id}/refunds/calculate.json"
    refund_url = "#{url}/admin/orders/#{order_id}/refunds.json"
    IntegrationServices::Services::Shopify::ShopifyOrderResource.any_instance.stubs(:http_get).returns(order_mock)
    IntegrationServices::Services::Shopify::ShopifyRefundResource.any_instance.stubs(:http_post).with(calculate_url, full_refund_calculate_hash.to_json).returns(calculate_mock)
    IntegrationServices::Services::Shopify::ShopifyRefundResource.any_instance.stubs(:http_post).with(refund_url, full_refund_hash.to_json).returns(response_mock)

    param = construct_params(version: 'private', id: installed_app.id, event: 'refund_full_order', payload: { orderId: order_id, lineItemId: line_item_id, store: 'fd-integration-private.myshopify.com' })
    post :fetch, param
    assert_response 200
    match_json JSON.parse(response)
  ensure
    IntegrationServices::Services::Shopify::ShopifyRefundResource.any_instance.unstub(:http_post)
    IntegrationServices::Services::Shopify::ShopifyOrderResource.any_instance.unstub(:http_get)
  end

  def test_shopify_refund_line_item
    installed_app = get_installed_app('shopify')
    installed_app.configs[:inputs]['disable_shopify_actions'] = false
    installed_app.save
    order_id = 1025918795834
    line_item_id = 2382039318586
    url = 'https://fd-integration-private.myshopify.com'
    order_json = fetch_order.to_json
    calculate_json = fetch_refund_calculate.to_json
    response = fetch_refund_response.to_json

    order_mock = get_response_mock(order_json, 200)
    calculate_mock = get_response_mock(calculate_json, 200)
    response_mock = get_response_mock(response, 201)

    calculate_url = "#{url}/admin/orders/#{order_id}/refunds/calculate.json"
    refund_url = "#{url}/admin/orders/#{order_id}/refunds.json"
    IntegrationServices::Services::Shopify::ShopifyOrderResource.any_instance.stubs(:http_get).returns(order_mock)
    IntegrationServices::Services::Shopify::ShopifyRefundResource.any_instance.stubs(:http_post).with(calculate_url, lineitem_refund_calculate_hash.to_json).returns(calculate_mock)
    IntegrationServices::Services::Shopify::ShopifyRefundResource.any_instance.stubs(:http_post).with(refund_url, lineitem_refund_hash.to_json).returns(response_mock)

    param = construct_params(version: 'private', id: installed_app.id, event: 'refund_line_item', payload: { orderId: order_id, lineItemId: line_item_id, store: 'fd-integration-private.myshopify.com' })
    post :fetch, param
    assert_response 200
    match_json JSON.parse(response)
  ensure
    IntegrationServices::Services::Shopify::ShopifyRefundResource.any_instance.unstub(:http_post)
    IntegrationServices::Services::Shopify::ShopifyOrderResource.any_instance.unstub(:http_get)
  end

  def test_shopfiy_fetch_orders
    order_json = fetch_order.to_json
    installed_app = get_installed_app('shopify')
    installed_app.configs[:inputs]['disable_shopify_actions'] = false
    installed_app.save
    order_mock = get_response_mock(order_json, 200)
    IntegrationServices::Services::Shopify::ShopifyCustomerResource.any_instance.stubs(:http_get).returns(order_mock)
    IntegrationServices::Services::Shopify::ShopifyOrderResource.any_instance.stubs(:http_get).returns(order_mock)
    param = construct_params(version: 'private', id: installed_app.id, event: 'fetch_orders', payload: { email: 'test120181211142937@yopmail.com' })
    post :fetch, param
    assert_response 200
  ensure
    IntegrationServices::Services::Shopify::ShopifyOrderResource.any_instance.unstub(:http_get)
    IntegrationServices::Services::Shopify::ShopifyCustomerResource.any_instance.unstub(:http_get)
  end

  def test_shopfiy_fetch_orders_from_phone
    order_json = fetch_order.to_json
    installed_app = get_installed_app('shopify')
    installed_app.configs[:inputs]['disable_shopify_actions'] = false
    installed_app.save
    order_mock = get_response_mock(order_json, 200)
    IntegrationServices::Services::Shopify::ShopifyCustomerResource.any_instance.stubs(:http_get).returns(order_mock)
    IntegrationServices::Services::Shopify::ShopifyOrderResource.any_instance.stubs(:http_get).returns(order_mock)
    param = construct_params(version: 'private', id: installed_app.id, event: 'fetch_orders', payload: { email: nil, phone: '9999999999' })
    post :fetch, param
    assert_response 200
  ensure
    IntegrationServices::Services::Shopify::ShopifyOrderResource.any_instance.unstub(:http_get)
    IntegrationServices::Services::Shopify::ShopifyCustomerResource.any_instance.unstub(:http_get)
  end

  def test_shopify_cancel_order_errors_on_shopify_action_disabled
    installed_app = get_installed_app('shopify')
    installed_app.configs[:inputs]['disable_shopify_actions'] = true
    installed_app.save
    param = construct_params(version: 'private', id: installed_app.id, event: 'cancel_order', payload: { email: 'test120181211142937@yopmail.com' })
    post :fetch, param
    assert_response 403
  end

  def test_shopify_refund_full_order_errors_on_shopify_action_disabled
    installed_app = get_installed_app('shopify')
    installed_app.configs[:inputs]['disable_shopify_actions'] = true
    installed_app.save
    param = construct_params(version: 'private', id: installed_app.id, event: 'refund_full_order', payload: { email: 'test120181211142937@yopmail.com' })
    post :fetch, param
    assert_response 403
  end

  def test_shopify_refund_line_item_errors_on_shopify_action_disabled
    installed_app = get_installed_app('shopify')
    installed_app.configs[:inputs]['disable_shopify_actions'] = true
    installed_app.save
    param = construct_params(version: 'private', id: installed_app.id, event: 'refund_line_item', payload: { email: 'test120181211142937@yopmail.com' })
    post :fetch, param
    assert_response 403
  end

  def test_already_installed_app
    freshsales_application_id = Integrations::Application.where(name: 'freshsales').first.id
    post :create, construct_params(version: 'private', name: 'freshsales', configs: { domain: 'ramkumar', auth_token: 'v_GNcz8s2BmhzOVsp4Oe_w', ghostvalue: '.freshsales.io' })
    match_json([bad_request_error_pattern('name', :already_installed, code: :already_installed, description: 'App is already installed')])
    assert_response 400
  end

  def test_install_new_app
    freshsales_application_id = Integrations::Application.where(name: 'freshsales').first.id
    Account.current.installed_applications.where(application_id: freshsales_application_id).first.delete
    post :create, construct_params(version: 'private', name: 'freshsales', configs: { domain: 'ramkumar', auth_token: 'v_GNcz8s2BmhzOVsp4Oe_w', ghostvalue: '.freshsales.io' })
    assert_equal freshsales_application_id, JSON.parse(response.body)['application_id']
    assert_response 200
  end

  def test_install_new_app_in_sprout_plan
    Account.current.revoke_feature(:marketplace)
    freshsales_application_id = Integrations::Application.where(name: 'freshsales').first.id
    Account.current.installed_applications.where(application_id: freshsales_application_id).first.delete
    post :create, construct_params(version: 'private', name: 'freshsales', configs: { domain: 'ramkumar', auth_token: 'v_GNcz8s2BmhzOVsp4Oe_w', ghostvalue: '.freshsales.io' })
    assert_equal JSON.parse(response.body)['message'], 'The Marketplace feature(s) is/are not supported in your plan. Please upgrade your account to use it.'
    assert_response 403
  end

  def lineitem_refund_calculate_hash
    {
      refund: {
        currency: "USD", 
        location_id: 13_114_900_538,
        refund_line_items: [
          {
            line_item_id: 2382039318586,
            quantity: 1
          }
        ]
      }
    }
  end

  def lineitem_refund_hash
    {
      refund: {
        currency: "USD",
        location_id: 13_114_900_538,
        refund_line_items: [
          {
            line_item_id: 2382039318586,
            quantity: 1
          }
        ],
        transactions: [
           {
              order_id: 1025918795834,
              kind: 'refund', 
              gateway: 'manual', 
              parent_id: 1152647921722,
              amount: '227.74', 
              currency: 'USD', 
              maximum_refundable: '769.36'
           }
        ]
      }
    }
  end

  def full_refund_calculate_hash
    {
      refund: {
        currency: "USD", 
        shipping: {
          full_refund: true
        },
        refund_line_items: [
          {
            line_item_id: 2382039318586,
            quantity: 1
          },
          {
            line_item_id: 2382039351354,
            quantity: 1
          }
        ],
        location_id: 13_114_900_538
      }
    }
  end

  def full_refund_hash
    {
      refund: {
        currency: "USD", 
        shipping: {
          full_refund: true
        },
        refund_line_items: [
          {
            line_item_id: 2382039318586,
            quantity: 1
          },
          {
            line_item_id: 2382039351354,
            quantity: 1
          }
        ],
        location_id: 13_114_900_538,
        transactions: [
           {
              order_id: 1025918795834,
              kind: 'refund', 
              gateway: 'manual', 
              parent_id: 1152647921722,
              amount: '227.74', 
              currency: 'USD', 
              maximum_refundable: '769.36'
           }
        ]
      }
    }
  end


  def fetch_order
    { 
     order: {
        id: 1025918795834,
        email: 'hackerspainters.4+20181121132828@gmail.com', 
        closed_at: nil,
        created_at: '2018-11-28T05:26:56-12:00', 
        updated_at: '2018-11-28T05:26:58-12:00', 
        number: 5271,
        note: '', 
        token: '2a0e0fc9d940ea705663a42d8c4ace87', 
        gateway: 'manual', 
        test: false,
        total_price: '769.36', 
        subtotal_price: '652.00', 
        total_weight: 56000,
        total_tax: '117.36', 
        taxes_included: false,
        currency: 'USD', 
        financial_status: 'paid', 
        confirmed: true,
        total_discounts: '0.00', 
        total_line_items_price: '652.00', 
        cart_token: nil,
        buyer_accepts_marketing: false,
        name: '#6271', 
        referring_site: nil,
        landing_site: nil,
        cancelled_at: nil,
        cancel_reason: nil,
        total_price_usd: '769.36', 
        checkout_token: nil,
        reference: nil,
        user_id: 19497058362,
        location_id: 13114900538,
        source_identifier: nil,
        source_url: nil,
        processed_at: '2018-11-28T05:26:56-12:00', 
        device_id: nil,
        phone: nil,
        customer_locale: nil,
        app_id: 1354745,
        browser_ip: nil,
        landing_site_ref: nil,
        order_number: 6271,
        discount_applications: [

        ],
        discount_codes: [

        ],
        note_attributes: [

        ],
        payment_gateway_names: [
           'manual'
        ],
        processing_method: 'manual', 
        checkout_id: nil,
        source_name: 'shopify_draft_order', 
        fulfillment_status: nil,
        tax_lines: [
           {
              price: '117.36', 
              rate: 0.18,
              title: 'IGST', 
              price_set: {
                 shop_money: {
                    amount: '117.36', 
                    currency_code: 'USD'
                 },
                 presentment_money: {
                    amount: '117.36', 
                    currency_code: 'USD'
                 }
              }
           }
        ],
        tags: '', 
        contact_email: 'hackerspainters.4+20181121132828@gmail.com', 
        order_status_url: 'https:\/\/checkout.shopify.com\/13325991994\/orders\/2a0e0fc9d940ea705663a42d8c4ace87\/authenticate?key=2f60188ce7422a8cc46daead570ea01b', 
        presentment_currency: 'USD', 
        total_line_items_price_set: {
           shop_money: {
              amount: '652.00', 
              currency_code: 'USD'
           },
           presentment_money: {
              amount: '652.00', 
              currency_code: 'USD'
           }
        },
        total_discounts_set: {
           shop_money: {
              amount: '0.00', 
              currency_code: 'USD'
           },
           presentment_money: {
              amount: '0.00', 
              currency_code: 'USD'
           }
        },
        total_shipping_price_set: {
           shop_money: {
              amount: '0.00', 
              currency_code: 'USD'
           },
           presentment_money: {
              amount: '0.00', 
              currency_code: 'USD'
           }
        },
        subtotal_price_set: {
           shop_money: {
              amount: '652.00', 
              currency_code: 'USD'
           },
           presentment_money: {
              amount: '652.00', 
              currency_code: 'USD'
           }
        },
        total_price_set: {
           shop_money: {
              amount: '769.36', 
              currency_code: 'USD'
           },
           presentment_money: {
              amount: '769.36', 
              currency_code: 'USD'
           }
        },
        total_tax_set: {
           shop_money: {
              amount: '117.36', 
              currency_code: 'USD'
           },
           presentment_money: {
              amount: '117.36', 
              currency_code: 'USD'
           }
        },
        total_tip_received: '0.0', 
        admin_graphql_api_id: 'gid:\/\/shopify\/Order\/1025918795834', 
        line_items: [
           {
              id: 2382039318586,
              variant_id: 20489541877818,
              title: 'Product - 20181017164101', 
              quantity: 1,
              price: '193.00', 
              sku: '', 
              variant_title: nil,
              vendor: 'Robel-Murray', 
              fulfillment_service: 'manual', 
              product_id: 2038439608378,
              requires_shipping: true,
              taxable: true,
              gift_card: false,
              name: 'Product - 20181017164101', 
              variant_inventory_management: nil,
              properties: [

              ],
              product_exists: true,
              fulfillable_quantity: 1,
              grams: 27000,
              total_discount: '0.00', 
              fulfillment_status: nil,
              price_set: {
                 shop_money: {
                    amount: '193.00', 
                    currency_code: 'USD'
                 },
                 presentment_money: {
                    amount: '193.00', 
                    currency_code: 'USD'
                 }
              },
              total_discount_set: {
                 shop_money: {
                    amount: '0.00', 
                    currency_code: 'USD'
                 },
                 presentment_money: {
                    amount: '0.00', 
                    currency_code: 'USD'
                 }
              },
              discount_allocations: [

              ],
              admin_graphql_api_id: 'gid:\/\/shopify\/LineItem\/2382039318586', 
              tax_lines: [
                 {
                    title: 'IGST', 
                    price: '34.74', 
                    rate: 0.18,
                    price_set: {
                       shop_money: {
                          amount: '34.74', 
                          currency_code: 'USD'
                       },
                       presentment_money: {
                          amount: '34.74', 
                          currency_code: 'USD'
                       }
                    }
                 }
              ]
           },
           {
              id: 2382039351354,
              variant_id: 20490883563578,
              title: 'Product - 20181017181257', 
              quantity: 1,
              price: '459.00', 
              sku: '', 
              variant_title: nil,
              vendor: 'Collins-Homenick', 
              fulfillment_service: 'manual', 
              product_id: 2038582018106,
              requires_shipping: true,
              taxable: true,
              gift_card: false,
              name: 'Product - 20181017181257', 
              variant_inventory_management: nil,
              properties: [

              ],
              product_exists: true,
              fulfillable_quantity: 1,
              grams: 29000,
              total_discount: '0.00', 
              fulfillment_status: nil,
              price_set: {
                 shop_money: {
                    amount: '459.00', 
                    currency_code: 'USD'
                 },
                 presentment_money: {
                    amount: '459.00', 
                    currency_code: 'USD'
                 }
              },
              total_discount_set: {
                 shop_money: {
                    amount: '0.00', 
                    currency_code: 'USD'
                 },
                 presentment_money: {
                    amount: '0.00', 
                    currency_code: 'USD'
                 }
              },
              discount_allocations: [

              ],
              admin_graphql_api_id: 'gid:\/\/shopify\/LineItem\/2382039351354', 
              tax_lines: [
                 {
                    title: 'IGST', 
                    price: '82.62', 
                    rate: 0.18,
                    price_set: {
                       shop_money: {
                          amount: '82.62', 
                          currency_code: 'USD'
                       },
                       presentment_money: {
                          amount: '82.62', 
                          currency_code: 'USD'
                       }
                    }
                 }
              ]
           }
        ],
        shipping_lines: [

        ],
        fulfillments: [

        ],
        refunds: [

        ],
        customer: {
           id: 1220069720122,
           email: 'hackerspainters.4+20181121132828@gmail.com', 
           accepts_marketing: false,
           created_at: '2018-11-21T01:28:30-12:00', 
           updated_at: '2018-11-28T05:26:58-12:00', 
           first_name: nil,
           last_name: nil,
           orders_count: 16,
           state: 'disabled', 
           total_spent: '769.36', 
           last_order_id: 1025918795834,
           note: nil,
           verified_email: true,
           multipass_identifier: nil,
           tax_exempt: false,
           phone: nil,
           tags: '', 
           last_order_name: '#6271', 
           currency: 'USD', 
           admin_graphql_api_id: 'gid:\/\/shopify\/Customer\/1220069720122'
        }
     }
   }
  end

  def fetch_refund_calculate
    { 
     refund: {
        shipping: {
           amount: '0.00', 
           tax: '0.00', 
           maximum_refundable: '0.00'
        },
        refund_line_items: [
           {
              quantity: 1,
              line_item_id: 2382039318586,
              location_id: nil,
              restock_type: 'no_restock', 
              price: '193.00', 
              subtotal: '193.00', 
              total_tax: '34.74', 
              discounted_price: '193.00', 
              discounted_total_price: '193.00', 
              total_cart_discount_amount: '0.00'
           }
        ],
        transactions: [
           {
              order_id: 1025918795834,
              kind: 'suggested_refund', 
              gateway: 'manual', 
              parent_id: 1152647921722,
              amount: '227.74', 
              currency: 'USD', 
              maximum_refundable: '769.36'
           }
        ],
        currency: 'USD'
     }
   }
  end

  def fetch_refund_response
    { 
     refund: {
        id: 32214188090,
        order_id: 1025918795834,
        created_at: '2018-11-28T05:27:49-12:00', 
        note: nil,
        user_id: nil,
        processed_at: '2018-11-28T05:27:49-12:00', 
        restock: false,
        admin_graphql_api_id: 'gid:\/\/shopify\/Refund\/32214188090', 
        refund_line_items: [
           {
              id: 56870436922,
              quantity: 1,
              line_item_id: 2382039318586,
              location_id: nil,
              restock_type: 'no_restock', 
              subtotal: 193.0,
              total_tax: 34.74,
              subtotal_set: {
                 shop_money: {
                    amount: '193.00', 
                    currency_code: 'USD'
                 },
                 presentment_money: {
                    amount: '193.00', 
                    currency_code: 'USD'
                 }
              },
              total_tax_set: {
                 shop_money: {
                    amount: '34.74', 
                    currency_code: 'USD'
                 },
                 presentment_money: {
                    amount: '34.74', 
                    currency_code: 'USD'
                 }
              },
              line_item: {
                 id: 2382039318586,
                 variant_id: 20489541877818,
                 title: 'Product - 20181017164101', 
                 quantity: 1,
                 price: '193.00', 
                 sku: '', 
                 variant_title: nil,
                 vendor: 'Robel-Murray', 
                 fulfillment_service: 'manual', 
                 product_id: 2038439608378,
                 requires_shipping: true,
                 taxable: true,
                 gift_card: false,
                 name: 'Product - 20181017164101', 
                 variant_inventory_management: nil,
                 properties: [

                 ],
                 product_exists: true,
                 fulfillable_quantity: 0,
                 grams: 27000,
                 total_discount: '0.00', 
                 fulfillment_status: nil,
                 price_set: {
                    shop_money: {
                       amount: '193.00', 
                       currency_code: 'USD'
                    },
                    presentment_money: {
                       amount: '193.00', 
                       currency_code: 'USD'
                    }
                 },
                 total_discount_set: {
                    shop_money: {
                       amount: '0.00', 
                       currency_code: 'USD'
                    },
                    presentment_money: {
                       amount: '0.00', 
                       currency_code: 'USD'
                    }
                 },
                 discount_allocations: [

                 ],
                 admin_graphql_api_id: 'gid:\/\/shopify\/LineItem\/2382039318586', 
                 tax_lines: [
                    {
                       title: 'IGST', 
                       price: '34.74', 
                       rate: 0.18,
                       price_set: {
                          shop_money: {
                             amount: '34.74', 
                             currency_code: 'USD'
                          },
                          presentment_money: {
                             amount: '34.74', 
                             currency_code: 'USD'
                          }
                       }
                    }
                 ]
              }
           }
        ],
        transactions: [
           {
              id: 1152651788346,
              order_id: 1025918795834,
              kind: 'refund', 
              gateway: 'manual', 
              status: 'success', 
              message: 'Refunded 227.74 from manual gateway', 
              created_at: '2018-11-28T05:27:49-12:00', 
              test: false,
              authorization: nil,
              location_id: nil,
              user_id: nil,
              parent_id: 1152647921722,
              processed_at: '2018-11-28T05:27:49-12:00', 
              device_id: nil,
              receipt: {

              },
              error_code: nil,
              source_name: '2303410', 
              amount: '227.74', 
              currency: 'USD', 
              admin_graphql_api_id: 'gid:\/\/shopify\/OrderTransaction\/1152651788346'
           }
        ],
        order_adjustments: [

        ]
     }
   }
  end

end
