require_relative '../../../../api/unit_test_helper'

class CrmUtilFakeController < ApplicationController
  include Integrations::CloudElements::Crm::CrmUtil

  def current_account
    Account.first
  end

  def element
    'salesforce_v2'
  end

  def service_obj(payload, metadata)
    IntegrationServices::Services::CloudElementsService.new(Integrations::InstalledApplication.new(configs: { inputs: {} }), payload, metadata)
  end

  def instance_object_definition(payload, metadata)
    true
  end

  def instance_transformation payload, metadata
    true
  end

  def get_element_configs instance_id
    [{ 'key' => 'event.poller.refresh_interval' }, { 'key' => 'event.notification.enabled' }]
  end

  def update_element_configs instance_id, payload
    true
  end

  def check_salesforce_v2_fields
    @installed_app = Integrations::InstalledApplication.new(configs: { inputs: {} })
    @metadata = {}
    salesforce_v2_metadata_fields
    head 200
  end

  def check_dynamics_v2_fields
    @installed_app = Integrations::InstalledApplication.new(configs: { inputs: {} })
    @metadata = {}
    dynamics_v2_metadata_fields
    head 200
  end

  def check_formula_payload
    payload = formula_instance_payload Faker::Name.name, Faker::Number.number(2), Faker::Name.name, true
    render json: { message: payload }
  end

  def check_integrated_resources_migrated_successfully
    @installed_app = Integrations::InstalledApplication.new(configs: { inputs: {} })
    migrate_integrated_resources
    head 200
  end

  def check_instance_hash
    gen_hash = instance_hash
    render json: { message: gen_hash }
  end

  def check_crm_element_metadata_fields
    @metadata = {}
    field_hash = crm_element_metadata_fields Faker::Lorem.word
    render json: { message: field_hash }
  end

  def check_fd_metadata_fields
    @element_config = {}
    field_value = fd_metadata_fields
    render json: { message: field_value }
  end

  def check_settings
    render_settings
    head 200
  end

  def check_application_config_hash
    @element_config = { 'objects' => ['contact'] }
    @installed_app = Integrations::InstalledApplication.new(configs: { inputs: {} })
    config_hash = get_app_configs Faker::Lorem.word, Faker::Number.number(5), Faker::Number.number(5), Faker::Number.number(5), Faker::Number.number(5)
    render json: { message: config_hash }
  end

  def check_element_metadata_fields
    @installed_app = Integrations::InstalledApplication.new(configs: { inputs: {} })
    meta_data_hash = get_metadata_fields
    render json: { message: meta_data_hash }
  end

  def check_element_object_transformation(params = {})
    @contact_metadata = {}
    @account_metadata = {}
    @installed_app = Integrations::InstalledApplication.new(configs: { inputs: {} })
    sync_hash = {
      'contact_synced' => [{
        'fd_field' => 'FDCONTACTID__c'
      }, {
        'fd_field' => 'Id'
      }],
      'contact_fields' => {
        'seek_fields' => ['FDCONTACTID__c'],
        'fields_hash' => {
          'FDCONTACTID__c' => Faker::Lorem.word,
          'Id' => Faker::Number.number(5)
        }
      },
      'account_synced' => [{
        'fd_field' => 'FDCONTACTID__c'
      }, {
        'fd_field' => 'Id'
      }],
      'account_fields' => {
        'seek_fields' => ['FDCONTACTID__c'],
        'fields_hash' => {
          'FDCONTACTID__c' => Faker::Lorem.word,
          'Id' => Faker::Number.number(5)
        }
      }
    }
    element_object_transformation sync_hash, Faker::Number.number(5), params[:type] || 'crm', true
    head 200
  end

  def check_synced_contacts_hash
    @element_config = {
      'fd_contact' => {
        'FDCONTACTID__c' => Faker::Lorem.word
      },
      'fd_company' => {
        'CreatedAt' => Time.now.to_i
      },
      'contact_fields' => {
        'Id' => 1
      },
      'account_fields' => {
        'Id' => 1
      },
      'existing_contacts' => [],
      'existing_companies' => []
    }
    @installed_app = Integrations::InstalledApplication.new(configs: { inputs: {} })
    construct_synced_contacts
    head 200
  end

  def check_contact_account_name_is_valid
    @installed_app = Integrations::InstalledApplication.new(configs: { inputs: {} })
    response_hash = {
      'records' => [{
        'accountId' => 1,
        'AccountName' => Faker::Lorem.word
      }, {
        'accountId' => 1,
        'AccountName' => Faker::Lorem.word
      }]
    }
    get_contact_account_name response_hash, {}
    head 200
  end

  def check_contact_accounts
    payload = { input: {} }
    @installed_app = Integrations::InstalledApplication.new(configs: { inputs: {} })
    get_contact_accounts payload
    head 200
  end

  def check_contact_account_id
    @installed_app = Integrations::InstalledApplication.new(configs: { inputs: {} })
    get_contact_account_ids Faker::Internet.email, {}
    head 200
  end

  def check_synced_objects_params
    sync_objects = get_synced_objects
    render json: { message: sync_objects, element_type: element_is_salesforce? }
  end

  def check_delete_elements
    @installed_app = Integrations::InstalledApplication.new(configs: { inputs: {} })
    @installed_app.stubs(:application).returns(@installed_app)
    @installed_app.stubs(:name).returns(Faker::Lorem.word)
    delete_element_instance_error Faker::Lorem.word, Faker::Number.number(5)
    delete_formula_instance_error Faker::Lorem.word, Faker::Number.number(5), 'crm'
    head 200
  end

  def check_sync_type
    type = check_sync_active 'crm'
    build_setting_configs
    render json: { sync_type: type }
  end
end

class CrmUtilFakeControllerTest < ActionController::TestCase
  include IntegrationServices::Services
  def controller_params
    {
      leads: [],
      lead_labels: [],
      element_configs: {
        objects: ['contract', 'order']
      },
      contracts: [],
      orders: [],
      order_labels: [],
      contract_labels: [],
      opportunity_view: {
        value: '1'
      },
      opportunities: [],
      opportunity_labels: [],
      agent_settings: {
        value: []
      },
      opportunity_stage_choices_ids: '1,2',
      opportunity_stage_choices: "#{Faker::Lorem.word},#{Faker::Lorem.word}",
      ticket_sync_option: {
        value: '1'
      }
    }
  end

  def test_salesforce_v2_fields
    installed_application = Integrations::InstalledApplication.new
    installed_application.stubs(:va_rules).returns([VaRule.new])
    installed_application.stubs(:save!).returns(true)
    VaRule.any_instance.stubs(:update_attribute).returns(true)
    IntegrationServices::Services::SalesforceV2Service.any_instance.stubs(:receive).returns(true)
    Integrations::InstalledApplication.stubs(:find_by_application_id).returns(installed_application)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    params = controller_params
    params['contract_view'] = { value: '1' }
    params['order_view'] = { value: '1' }
    @controller.params = params
    @controller.stubs(:action_name).returns('check_salesforce_v2_fields')
    @controller.send(:check_salesforce_v2_fields)
    assert_response 200
  ensure
    IntegrationServices::Services::SalesforceV2Service.any_instance.unstub(:receive)
  end

  def test_dynamics_v2_fields
    IntegrationServices::Services::SalesforceV2Service.any_instance.stubs(:receive).returns(true)
    VaRule.any_instance.stubs(:update_attribute).returns(true)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    params = controller_params
    params['contract_view'] = { value: '0' }
    params['order_view'] = { value: '0' }
    @controller.params = params
    @controller.stubs(:action_name).returns('check_dynamics_v2_fields')
    @controller.send(:check_dynamics_v2_fields)
    assert_response 200
  ensure
    IntegrationServices::Services::SalesforceV2Service.any_instance.unstub(:receive)
    VaRule.any_instance.unstub(:update_attribute)
  end

  def test_fetch_saleforce_v2_params_raises_exception
    Integrations::InstalledApplication.any_instance.stubs(:va_rules).returns([VaRule.new])
    VaRule.any_instance.stubs(:update_attribute).raises(RuntimeError)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    params = controller_params
    params['contract_view'] = { value: '1' }
    params['order_view'] = { value: '1' }
    @controller.params = params
    @controller.stubs(:action_name).returns('check_salesforce_v2_fields')
    @controller.send(:check_salesforce_v2_fields)
    assert_response 200
  ensure
    Integrations::InstalledApplication.any_instance.unstub(:va_rules)
  end

  def test_fetch_dynamics_v2_params_raises_exception
    params = controller_params
    params.delete(:element_configs)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.params = params
    @controller.stubs(:action_name).returns('check_dynamics_v2_fields')
    @controller.send(:check_dynamics_v2_fields)
    assert_response 200
  end

  def test_opportunity_params_fetch_raise_exception
    IntegrationServices::Services::SalesforceV2Service.any_instance.stubs(:receive).returns(true)
    VaRule.any_instance.stubs(:update_attribute).returns(true)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    params = controller_params
    params.delete(:opportunity_view)
    params['contract_view'] = { value: '0' }
    params['order_view'] = { value: '0' }
    @controller.params = params
    @controller.stubs(:action_name).returns('check_dynamics_v2_fields')
    @controller.send(:check_dynamics_v2_fields)
    assert_response 200
  ensure
    IntegrationServices::Services::SalesforceV2Service.any_instance.unstub(:receive)
    VaRule.any_instance.unstub(:update_attribute)
  end

  def test_formula_payload
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_formula_payload')
    @controller.send(:check_formula_payload)
    assert_response 200
    assert JSON.parse(JSON.parse(response.body)['message'])['active'].to_bool
  end

  def test_integrated_resources_migration
    Account.stubs(:current).returns(Account.first)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_integrated_resources_migrated_successfully')
    @controller.send(:check_integrated_resources_migrated_successfully)
    assert_response 200
  ensure
    Account.unstub(:current)
  end

  def test_instance_hash_generated_correctly_for_salesforce_v2
    Redis::KeyValueStore.any_instance.stubs(:get_key).returns({ oauth_token: '1', refresh_token: '1' }.to_json)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_instance_hash')
    @controller.send(:check_instance_hash)
    assert_response 200
    assert_equal JSON.parse(response.body)['message']['element_name'], 'salesforce_v2_localhost_1'
  ensure
    Redis::KeyValueStore.any_instance.unstub(:get_key)
  end

  def test_instance_hash_generated_correctly_for_dynamics_v2
    Redis::KeyValueStore.any_instance.stubs(:get_key).returns({ oauth_token: '1', refresh_token: '1' }.to_json)
    response = ActionDispatch::TestResponse.new
    @controller.stubs(:element).returns('dynamics_v2')
    @controller.response = response
    @controller.stubs(:action_name).returns('check_instance_hash')
    @controller.send(:check_instance_hash)
    assert_response 200
    assert_equal JSON.parse(response.body)['message']['element_name'], 'dynamics_v2_localhost_1'
  ensure
    Redis::KeyValueStore.any_instance.unstub(:get_key)
    @controller.unstub(:element)
  end

  def test_element_metadata_fields
    cloud_element_response = {
      'fields' => [{
        'vendorDisplayName' => Faker::Lorem.word,
        'vendorPath' => 'StageName',
        'vendorNativeType' => 'String',
        'picklistValues' => [{
          'value' => Faker::Lorem.word
        }]
      }]
    }
    IntegrationServices::Services::CloudElementsService.any_instance.stubs(:receive).returns(cloud_element_response)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_crm_element_metadata_fields')
    @controller.send(:check_crm_element_metadata_fields)
    parsed_response = JSON.parse(response.body)
    assert_response 200
    assert_includes parsed_response['message']['contact_fields'], 'Id'
    assert_includes parsed_response['message']['contact_fields'], 'FDCONTACTID__c'
    assert_includes parsed_response['message']['account_fields'], 'Id'
    assert_includes parsed_response['message']['account_fields'], 'FDACCOUNTID__c'
  ensure
    IntegrationServices::Services::CloudElementsService.any_instance.unstub(:receive)
  end

  def test_fd_metadata_fields
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_fd_metadata_fields')
    @controller.send(:check_fd_metadata_fields)
    parsed_response = JSON.parse(response.body)
    assert_response 200
    assert_equal parsed_response['message']['Company Name'], 'text'
    assert_equal parsed_response['message']['Description'], 'paragraph'
  end

  def test_rendering_of_settings
    ActionView::Renderer.any_instance.stubs(:render).returns('')
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_settings')
    @controller.send(:check_settings)
    assert_response 200
  ensure
    ActionView::Renderer.any_instance.unstub(:render)
  end

  def test_app_config_hash
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:element).returns('dynamics_v2')
    @controller.stubs(:action_name).returns('check_application_config_hash')
    @controller.send(:check_application_config_hash)
    parsed_response = JSON.parse(response.body)
    assert_response 200
    assert_equal parsed_response['message']['crm_sync_type'], 'FD_AND_CRM'
    assert_includes parsed_response['message']['companies']['fd_fields'], 'name'
  ensure
    @controller.unstub(:element)
  end

  def test_metadata_hash
    params = {
      contract_view: { value: '1' },
      order_view: { value: '1' },
      enable_sync: true,
      inputs: {
        companies: [{
          'sf_field' => Faker::Lorem.word,
          'fd_field' => Faker::Lorem.word
        }],
        contacts: [{
          'sf_field' => Faker::Lorem.word,
          'fd_field' => Faker::Lorem.word
        }],
        contact_labels: [Faker::Lorem.word],
        crm_sync_type: 1,
        master_type: 1,
        sync_frequency: 1
      }
    }.merge(controller_params)
    params[:opportunity_view][:value] = '0'
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.params = params
    @controller.stubs(:element).returns('dynamics_v2')
    @controller.stubs(:action_name).returns('check_element_metadata_fields')
    @controller.send(:check_element_metadata_fields)
    assert_response 200
  end

  def test_object_transformation_for_synced_crm
    params = {
      enable_sync: 'on',
      crm_sync_type: 'off',
      sync_frequency: 1
    }
    Integrations::InstalledApplication.any_instance.stubs(:configs_enable_sync).returns('off')
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.params = params
    @controller.stubs(:action_name).returns('check_element_object_transformation')
    @controller.send(:check_element_object_transformation)
    assert_response 200
  ensure
    Integrations::InstalledApplication.any_instance.unstub(:configs_enable_sync)
  end

  def test_object_transformation_for_unsynced_crm
    params = {
      enable_sync: 'on',
      crm_sync_type: 'on',
      sync_frequency: 1
    }
    Integrations::InstalledApplication.any_instance.stubs(:configs_crm_sync_type).returns('off')
    Integrations::InstalledApplication.any_instance.stubs(:configs_enable_sync).returns('on')
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.params = params
    @controller.stubs(:action_name).returns('check_element_object_transformation')
    @controller.send(:check_element_object_transformation)
    assert_response 200
  ensure
    Integrations::InstalledApplication.any_instance.unstub(:configs_enable_sync)
    Integrations::InstalledApplication.any_instance.unstub(:configs_crm_sync_type)
  end

  def test_object_transformation_for_unsynced_dynamics
    params = {
      enable_sync: 'on',
      crm_sync_type: 'on',
      sync_frequency: 1
    }
    Integrations::InstalledApplication.any_instance.stubs(:configs_crm_sync_type).returns('off')
    Integrations::InstalledApplication.any_instance.stubs(:configs_enable_sync).returns('on')
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.params = params

    @controller.stubs(:action_name).returns('check_element_object_transformation')
    @controller.send(:check_element_object_transformation, type: 'fd')
    assert_response 200
  ensure
    Integrations::InstalledApplication.any_instance.unstub(:configs_crm_sync_type)
    Integrations::InstalledApplication.any_instance.unstub(:configs_enable_sync)
  end

  def test_synced_contacts_hash
    contacts_synced = {
      'fd_fields' => ['FDCONTACTID__c'],
      'sf_fields' => ['Id']
    }
    account_synced = {
      'fd_fields' => ['CreatedAt'],
      'sf_fields' => ['Id']
    }
    Integrations::InstalledApplication.any_instance.stubs(:configs_contacts).returns(contacts_synced)
    Integrations::InstalledApplication.any_instance.stubs(:configs_companies).returns(account_synced)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_synced_contacts_hash')
    @controller.send(:check_synced_contacts_hash)
    assert_response 200
  ensure
    Integrations::InstalledApplication.any_instance.unstub(:configs_contacts)
    Integrations::InstalledApplication.any_instance.unstub(:configs_companies)
  end

  def test_contact_account_name_is_valid_for_salesforce_crm
    Integrations::InstalledApplication.any_instance.stubs(:configs_contact_fields).returns('AccountName,Id')
    account_response = [{
      'Id' => 1,
      'Name' => Faker::Lorem.word
    }, {
      'Id' => 2,
      'Name' => Faker::Lorem.word
    }]
    IntegrationServices::Services::CloudElementsService.any_instance.stubs(:receive).returns(account_response)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_contact_account_name_is_valid')
    @controller.send(:check_contact_account_name_is_valid)
    assert_response 200
  ensure
    Integrations::InstalledApplication.any_instance.unstub(:configs_contact_fields)
    IntegrationServices::Services::CloudElementsService.any_instance.unstub(:receive)
  end

  def test_contact_account_name_is_valid_for_dynamics_crm
    Integrations::InstalledApplication.any_instance.stubs(:configs_contact_fields).returns('AccountName,Id')
    account_response = [{
      'attributes' => {
        'accountid' => 1,
        'name' => Faker::Lorem.word
      }
    }, {
      'attributes' => {
        'accountid' => 2,
        'name' => Faker::Lorem.word
      }
    }]
    IntegrationServices::Services::CloudElementsService.any_instance.stubs(:receive).returns(account_response)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:element).returns('dynamics_v2')
    @controller.stubs(:action_name).returns('check_contact_account_name_is_valid')
    @controller.send(:check_contact_account_name_is_valid)
    assert_response 200
  ensure
    @controller.unstub(:element)
    Integrations::InstalledApplication.any_instance.unstub(:configs_contact_fields)
    IntegrationServices::Services::CloudElementsService.any_instance.unstub(:receive)
  end

  def test_contact_accounts_fetched_correctly
    IntegrationServices::Services::CloudElementsService.any_instance.stubs(:receive).returns(true)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_contact_accounts')
    @controller.send(:check_contact_accounts)
    assert_response 200
  ensure
    IntegrationServices::Services::CloudElementsService.any_instance.unstub(:receive)
  end

  def test_contact_account_id_fetched_correctly
    IntegrationServices::Services::CloudElementsService.any_instance.stubs(:receive).returns(true)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_contact_account_id')
    @controller.send(:check_contact_account_id)
    assert_response 200
  ensure
    IntegrationServices::Services::CloudElementsService.any_instance.unstub(:receive)
  end

  def test_synced_objects_params
    params = {
      inputs: {
        contacts: [],
        companies: []
      }
    }
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.params = params
    @controller.stubs(:action_name).returns('check_synced_objects_params')
    @controller.send(:check_synced_objects_params)
    assert_response 200
    assert JSON.parse(response.body)['element_type']
  end

  def test_delete_elements
    IntegrationServices::Services::CloudElementsService.any_instance.stubs(:receive).returns(true)
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('check_delete_elements')
    @controller.send(:check_delete_elements)
    assert_response 200
  ensure
    IntegrationServices::Services::CloudElementsService.any_instance.unstub(:receive)
  end

  def test_sync_type
    params = {
      enable_sync: 'on',
      crm_sync_type: 'CRM_to_FD'
    }
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.params = params
    @controller.stubs(:action_name).returns('check_sync_type')
    @controller.send(:check_sync_type)
    assert_response 200
    assert JSON.parse(response.body)['sync_type']
  end
end
