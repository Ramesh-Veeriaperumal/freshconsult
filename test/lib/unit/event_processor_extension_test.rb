require_relative '../test_helper'
require 'minitest/spec'
require 'webmock/minitest'

class EventProcessorExtensionTest < ActiveSupport::TestCase
  def setup
    super
    @test_obj = Object.new
    @test_obj.extend(Freshid::V2::EventProcessorExtensions)
    @user = create_test_account
    @account = @user.account.make_current
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(true)
  end

  def teardown
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
  end

  def test_freshid_default_sso_setup
    payload = {
        "actor"=>{"actor_type"=>"USER", "user_agent"=>"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.122 Safari/537.36", "ip_address"=>"40.131.47.162", "actor_name"=>"mpocock@misshalls.org", "actor_id"=>"145854596706551922"},
        "authentication_module"=>{
            "enable"=>true,
            "enforcement_level"=>"N/A",
            "id"=>"152516591931284152",
            "organisation_id"=>"145854596672997485",
            "debug_enabled"=>true,
            "type"=>"SAML",
            "update_time"=>"2020-02-25T22:12:43Z"
        },
        "event_type"=>"AUTHENTICATION_MODULE_UPDATED",
        "organisation_id"=>"145854596672997485",
        "request_id"=>"65afe207da204222-541bf429b3e33204-1-693a3f5837d6a0c9",
        "action_epoch"=>1582668763.283
    }.deep_symbolize_keys


    @test_obj.authentication_module_updated_event_callback(payload)
    assert "true", @account.sso_enabled.to_s
    assert "true", @account.freshid_saml_sso_enabled?.to_s
  end

  def test_freshid_default_sso_setup_disable
    payload = {
        "actor"=>{"actor_type"=>"USER", "user_agent"=>"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.122 Safari/537.36", "ip_address"=>"40.131.47.162", "actor_name"=>"mpocock@misshalls.org", "actor_id"=>"145854596706551922"},
        "authentication_module"=>{
            "enable"=>false,
            "enforcement_level"=>"N/A",
            "id"=>"152516591931284152",
            "organisation_id"=>"145854596672997485",
            "debug_enabled"=>true,
            "type"=>"SAML",
            "update_time"=>"2020-02-25T22:12:43Z"
        },
        "event_type"=>"AUTHENTICATION_MODULE_UPDATED",
        "organisation_id"=>"145854596672997485",
        "request_id"=>"65afe207da204222-541bf429b3e33204-1-693a3f5837d6a0c9",
        "action_epoch"=>1582668763.283
    }.deep_symbolize_keys


    @test_obj.authentication_module_updated_event_callback(payload)
    assert "false", @account.sso_enabled.to_s
    assert "false", @account.freshid_saml_sso_enabled?.to_s
  end

  def test_freshid_custom_policy_updated_event_with_freshid_sso_sync
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(true)
    sso_config = { password: true, google: false, saml: false }
    payload = payload_content(sso_config, 'AGENT', 'ENTRYPOINT_UPDATED', @account.full_domain)
    @test_obj.instance_variable_set('@event_type', 'ENTRYPOINT_UPDATED')
    @test_obj.safe_send('update_accounts', payload)
    assert @account.freshid_custom_policy_enabled?(:agent).nil?.equal?(false), 'Custom Policy Should be enabled for agent'
    assert @account.sso_enabled.equal?(false), 'SSO Should be disabled'
  ensure
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
  end

  def test_freshid_custom_policy_updated_event_with_all_auth_disabled
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(true)
    sso_config = { password: false, google: false, saml: false }
    config = { entrypoint_enabled: false }
    payload = payload_content(sso_config, 'AGENT', 'ENTRYPOINT_UPDATED', @account.full_domain, config)
    @test_obj.instance_variable_set('@event_type', 'ENTRYPOINT_UPDATED')
    @test_obj.safe_send('update_accounts', payload)
    assert @account.freshid_custom_policy_enabled?(:agent).nil?.equal?(true), 'Custom Policy Should be disable for agent'
    assert @account.sso_enabled.equal?(false), 'SSO Should be disabled'
  ensure
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
  end

  def test_freshid_custom_policy_deleted_event_with_freshid_sso_sync
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(true)
    sso_config = { password: true, google: false, saml: false }
    payload = payload_content(sso_config, 'AGENT', 'ENTRYPOINT_DELETED', @account.full_domain)
    @test_obj.instance_variable_set('@event_type', 'ENTRYPOINT_DELETED')
    @test_obj.safe_send('update_accounts', payload)
    assert @account.freshid_custom_policy_enabled?(:agent).nil?.equal?(true), 'Custom Policy Should be disabled for agent'
    assert @account.sso_enabled.equal?(false), 'SSO Should be disabled'
  ensure
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
  end

  def test_freshid_custom_policy_updated_event_with_invalid_domain
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(true)
    sso_config = { password: true, google: false, saml: false }
    payload = payload_content(sso_config, 'AGENT', 'ENTRYPOINT_UPDATED', 'asampledomaininvalid.freshpo.com')
    @test_obj.instance_variable_set('@event_type', 'ENTRYPOINT_UPDATED')
    mock = Minitest::Mock.new
    mock.expect(:call, true,  ['FRESHID CUSTOM POLICY :: EVENT PROCESSOR EXTENSIONS ::  Error while updating entrypoint event ENTRYPOINT_UPDATED : org 145854596672997485 : entry id '])
    Rails.logger.stub :error, mock do
      @test_obj.safe_send('update_accounts', payload)
    end
    assert_equal mock.verify, true
  ensure
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
  end

  def test_freshid_custom_policy_updated_without_sso_agent_event
    sso_config = { password: true, google: false, saml: false }
    payload = payload_content(sso_config, 'AGENT', 'ENTRYPOINT_UPDATED', @account.full_domain)
    trigger_event(:updated, payload)
    assert @account.freshid_custom_policy_enabled?(:agent).nil?.equal?(false), 'Custom Policy Should be enabled for agent'
    assert @account.sso_enabled.equal?(false), 'SSO Should be disabled'
  end

  def test_freshid_custom_policy_updated_without_sso_contact_event
    sso_config = { password: false, google: true, saml: false }
    payload = payload_content(sso_config, 'CONTACT', 'ENTRYPOINT_UPDATED', @account.full_domain)
    trigger_event(:updated, payload)
    assert @account.freshid_custom_policy_enabled?(:contact).nil?.equal?(false), 'Custom Policy Should be enabled for contact'
    assert @account.sso_enabled.equal?(false), 'SSO Should be disabled'
  end

  def test_freshid_custom_policy_update_with_same_entrypoint_different_user
    sso_config = { password: false, google: true, saml: false }
    payload = payload_content(sso_config, 'AGENT', 'ENTRYPOINT_UPDATED', @account.full_domain)
    trigger_event(:updated, payload)
    payload = payload_content(sso_config, 'CONTACT', 'ENTRYPOINT_UPDATED', @account.full_domain)
    trigger_event(:updated, payload)
    assert @account.freshid_custom_policy_enabled?(:agent).nil?.equal?(true), 'Custom Policy Should be disabled for contact'
    assert @account.freshid_custom_policy_enabled?(:contact).nil?.equal?(false), 'Custom Policy Should be enabled for agent'
    assert @account.sso_enabled.equal?(false), 'SSO Should be disabled'
  end

  def test_freshid_custom_policy_sso_setup
    Account.current.stubs(:freshid_integration_enabled?).returns(true)
    sso_config = { password: true, google: false, saml: true }
    payload = payload_content(sso_config, 'AGENT', 'ENTRYPOINT_UPDATED', @account.full_domain)
    trigger_event(:updated, payload)
    assert @account.sso_enabled.equal?(true), 'SSO Should be enabled'
    assert @account.freshid_sso_enabled?.equal?(true), 'FESHSID SSO Should be enabled'
  ensure
    Account.current.unstub(:freshid_integration_enabled?)
  end

  def test_freshid_custom_policy_deleted_event
    sso_config = { password: true, google: false, saml: false }
    payload = payload_content(sso_config, 'AGENT', 'ENTRYPOINT_DELETED', @account.full_domain)
    trigger_event(:deleted, payload)
    assert @account.sso_enabled.equal?(false), 'SSO Should be disabled'
    assert @account.freshid_sso_enabled?.equal?(false), 'FESHSID SSO Should be disabled'
  end

  def test_freshid_custom_policy_accounts_removed_without_accounts
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(true)

    account_details = [
      {
        organisation_id: 12_345,
        domain: @account.full_domain,
        product_id: FRESHID_V2_PRODUCT_ID.to_s
      },
      {
        organisation_id: 12_345,
        domain: 'testdomain.testapp.com',
        product_id: '007'
      }
    ]
    org = create_organisation(12_345, 'test.freshworks.com')
    create_organisation_account_mapping(@account, org.id)
    metadata = { page_number: 1, page_size: 2, has_more: false }
    freshid_response = org_freshid_response(account_details, metadata)
    Freshid::V2::Models::Account.stubs(:organisation_accounts).returns(freshid_response)

    sso_config = { password: true, google: false, saml: false }
    config = { organisation_id: 12_345 }
    payload = payload_content(sso_config, 'AGENT', 'ENTRYPOINT_UPDATED', @account.full_domain, config)
    @test_obj.instance_variable_set('@event_type', 'ENTRYPOINT_UPDATED')
    @test_obj.safe_send('update_accounts', payload)
    assert @account.freshid_custom_policy_enabled?(:agent).nil?.equal?(false), 'Custom Policy Should be enabled for agent'

    payload[:entrypoint].delete(:accounts)
    @test_obj.safe_send('update_accounts', payload)
    @account.reload
    assert @account.freshid_custom_policy_enabled_for_account?.nil?.equal?(true), 'Custom Policy Should be Disabled for Agent'
  ensure
    delete_organisation(org.id) if org
    Freshid::V2::Models::Account.unstub(:organisation_accounts)
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
  end

  def test_freshid_custom_policy_accounts_removed_with_accounts
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(true)
    org = create_organisation(12_345, 'test.freshworks.com')
    create_organisation_account_mapping(@account, org.id)

    account_details = [
      {
        organisation_id: 12_345,
        domain: @account.full_domain,
        product_id: FRESHID_V2_PRODUCT_ID.to_s
      },
      {
        organisation_id: 12_345,
        domain: 'sampletest.freshpo.com',
        product_id: FRESHID_V2_PRODUCT_ID.to_s
      }
    ]
    metadata = { page_number: 1, page_size: 2, has_more: false }
    freshid_response = org_freshid_response(account_details, metadata)
    Freshid::V2::Models::Account.stubs(:organisation_accounts).returns(freshid_response)

    sso_config = { password: true, google: false, saml: false }
    config = { organisation_id: 12_345 }
    payload = payload_content(sso_config, 'AGENT', 'ENTRYPOINT_UPDATED', @account.full_domain, config)
    @test_obj.instance_variable_set('@event_type', 'ENTRYPOINT_UPDATED')
    @test_obj.safe_send('update_accounts', payload)
    assert @account.freshid_custom_policy_enabled?(:agent).nil?.equal?(false), 'Custom Policy Should be enabled for agent'

    DomainMapping.create(domain: 'sampletest.freshpo.com', account_id: SecureRandom.random_number.to_s[2..4].to_i)
    payload[:entrypoint][:accounts].first[:domain] = 'sampletest.freshpo.com'
    @test_obj.safe_send('update_accounts', payload)
    @account.reload
    assert @account.freshid_custom_policy_enabled_for_account?.nil?.equal?(true), 'Custom Policy Should be Disabled for Agent'
  ensure
    delete_organisation(org.id) if org
    Freshid::V2::Models::Account.unstub(:organisation_accounts)
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
    DomainMapping.find_by_domain('sampletest.freshpo.com').destroy if DomainMapping.find_by_domain('sampletest.freshpo.com')
  end

  def test_paginated_org_accounts_entrypoint_removal
    Account.any_instance.stubs(:freshid_sso_sync_enabled?).returns(true)
    account_details = [
      {
        organisation_id: 12_345,
        domain: @account.full_domain,
        product_id: FRESHID_V2_PRODUCT_ID.to_s
      },
      {
        organisation_id: 12_345,
        domain: 'testdomain.testapp.com',
        product_id: '007'
      }
    ]
    org = create_organisation(12_345, 'test.freshworks.com')
    create_organisation_account_mapping(@account, org.id)
    metadata = { page_number: 1, page_size: 2, has_more: false }
    freshid_response = org_freshid_response(account_details, metadata)
    Freshid::V2::Models::Account.stubs(:organisation_accounts).returns(freshid_response)

    sso_config = { password: true, google: false, saml: false }
    config = { organisation_id: 12_345 }
    payload = payload_content(sso_config, 'AGENT', 'ENTRYPOINT_UPDATED', @account.full_domain, config)
    @test_obj.instance_variable_set('@event_type', 'ENTRYPOINT_UPDATED')
    @test_obj.safe_send('update_accounts', payload)
    assert @account.freshid_custom_policy_enabled?(:agent).nil?.equal?(false), 'Custom Policy Should be enabled for agent'
    payload[:entrypoint].delete(:accounts)

    @test_obj.safe_send('paginated_org_accounts_entrypoint_removal', 2, 'test.freshworks.com', '159325420343738375', [])

    @account.reload
    assert @account.freshid_custom_policy_enabled_for_account?.nil?.equal?(true), 'Custom Policy Should be Disabled for Agent'
  ensure
    delete_organisation(org.id) if org
    Freshid::V2::Models::Account.unstub(:organisation_accounts)
    Account.any_instance.unstub(:freshid_sso_sync_enabled?)
  end

  private

    def trigger_event(event, payload)
      if event == :updated
        @test_obj.safe_send('process_freshid_custom_policy_events', payload[:entrypoint])
      else
        @test_obj.safe_send('process_entrypoint_deleted_event', payload[:entrypoint][:entrypoint_id])
      end
    end

    def payload_content(sso_config, entity, event, account_domain, configs = {})
      {
        actor: {
          actor_id: '148031922714001456',
          actor_type: 'USER',
          actor_name: 'ronak.poriya@freshworks.com',
          user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.14; rv74.0) Gecko/20100101 Firefox/74.0'
        },
        entrypoint: {
          portals: [{ name: 'secsettkngs_swiggy', url: 'http//swiggy.freshdesk.com/swiggyDunzo', id: '159326119446134795', account_id: '148031922663669877', organisation_id: '145854596672997485' }],
          entrypoint_enabled: configs[:entrypoint_enabled].nil? ? true : configs[:entrypoint_enabled],
          slug: 'entry2',
          modules: [
            {
              enabled: sso_config[:password],
              config: {
                size: 8,
                logo_uri: '/assets/images/works.svg',
                enforcement_level: 'PASSWORD_CHANGE',
                password_expiry_days: 0,
                display_name: 'Login with password',
                ui_redirect_uri: 'https//secsettings.vahlok.freshworksapi.io/sp/PASSWORD/148031922600755244/login',
                logout_url: ' ',
                history_count: 0,
                policy_level: 'LOW',
                special_characters_count: 0,
                numeric_characters_count: 0,
                mixed_case_characters_count: 0,
                type: 'PASSWORD',
                session_max_inactive: 0
              },
              id: '148031922600755244',
              debug_enabled: false,
              type: 'PASSWORD',
              custom_sso: false,
              entrypoint_id: '159325420343738375'
            },
            {
              enabled: sso_config[:google],
              config: {
                logo_uri: 'https//accounts.vahlok.freshworksapi.io/assets/images/google_logo.svg',
                token_uri: 'https//oauth2.googleapis.com/token',
                scopes: 'openid,email,profile', display_name: 'Login with google',
                ui_redirect_uri: 'https//accounts.vahlok.freshworksapi.io/sp/OIDC/119746749815914501/login',
                redirect_uri: 'https//accounts.vahlok.freshworksapi.io/sp/OIDC/119746749815914501/callback',
                client_id: '252648225933-9969rij4m6of2uuheomkn28gb6qv8tp7.apps.googleusercontent.com',
                authorization_uri: 'https//accounts.google.com/o/oauth2/v2/auth',
                claims: { first_name: 'given_name', email_verified: true, company_name: 'company_name', email: 'email', job_title: 'job_title', id: 'sub', last_name: 'family_name', middle_name: 'middle_name', mobile: 'mobile', phone: 'phone_number' },
                client_secret: 'dK_HwArKrS2BpxtVHJzowl4z',
                enable_signature_validation: true,
                type: 'oidc'
              },
              id: '119746749815914501',
              debug_enabled: false,
              type: 'GOOGLE',
              custom_sso: false,
              entrypoint_id: '159325420343738375'
            },
            {
              enabled: sso_config[:saml],
              config: {
                signing_options: 'ASSERTION_UNSIGNED_MESSAGE_SIGNED',
                ui_redirect_uri: 'https//dashingcars.vahlok.freshworksapi.io/sp/SAML/162108483188293633/login',
                entity_url: 'https//dashingcars.vahlok.freshworksapi.io/sp/SAML/162108483188293633/metadata',
                type: 'SAML',
                session_max_inactive: 0,
                saml_http_binding: 'HTTP_POST',
                assertion_url: 'https//dashingcars.vahlok.freshworksapi.io/sp/SAML/162108483188293633/callback'
              },
              id: '162108483188293633',
              debug_enabled: true,
              type: 'SAML',
              custom_sso: true,
              entrypoint_id: '159325420343738375'
            }
          ],
          user_type: entity,
          entrypoint_url: 'https//secsettings.vahlok.freshworksapi.io/login/auth/entry2',
          organisation_id: configs[:organisation_id] || '145854596672997485',
          title: 'Custom Method 22',
          entrypoint_id: '159325420343738375',
          accounts: [{
            name: 'secsettting',
            domain: account_domain,
            id: '148031922663669877',
            status: 'ACTIVATED',
            organisation_id: configs[:organisation_id] || '145854596672997485',
            product_id: FRESHID_V2_PRODUCT_ID.to_s,
            external_id: '1',
            update_time: '2020-02-13T114600Z',
            create_time: '2020-02-13T114600Z'
          }]
        },
        event_type: event,
        organisation_id: configs[:organisation_id] || '145854596672997485',
        request_id: '690c2927e12026bd-d6293b662528bc7f-1-4c066f9ed04d05e3',
        action_epoch: 1_585_717_412.123
      }
    end

    def create_organisation(org_id, org_domain)
      Organisation.stubs(:organisation_account_mapping).returns(true)
      Organisation.create(organisation_id: org_id, domain: org_domain)
    ensure
      Organisation.unstub(:organisation_account_mapping)
    end

    def delete_organisation(org_id)
      OrganisationAccountMapping.find_by_organisation_id(org_id).destroy if OrganisationAccountMapping.find_by_organisation_id(org_id)
    end

    def create_organisation_account_mapping(account, org_id)
      OrganisationAccountMapping.create(account_id: account.id, organisation_id: org_id)
    end

    def org_freshid_response(account_details = [], metadata = {})
      accounts = []
      account_details.each do |account|
        account_hash = {
          create_time: 1_589_629_283_000_000_000,
          update_time: 1_589_629_283_000_000_000,
          id: '181732831288921786',
          organisation_id: account[:organisation_id],
          product_id: account[:product_id],
          name: nil,
          domain: account[:domain],
          description: nil,
          url: nil,
          locale: nil,
          time_zone: nil,
          status: :ACTIVATED,
          external_id: nil,
          region_code: :UNSPECIFIED
        }
        accounts << account_hash
      end
      {
        accounts: accounts,
        total_size: accounts.count,
        page_number: metadata[:page_number],
        page_size: metadata[:page_size],
        has_more: metadata[:has_more]
      }
    end
end
