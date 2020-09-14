require Rails.root.join('test', 'models', 'helpers', 'freshchat_account_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'freshcaller_account_test_helper.rb')

module BillingTestHelper
  include FreshchatAccountTestHelper
  include FreshcallerAccountTestHelper

  def omni_upgrade_event_content
    {
      customer: {
        id: @account.id,
        auto_collection: 'on'
      },
      subscription: {
        plan_id: Billing::Subscription.helpkit_plan.key('estate_omni_jan_20').dup,
        plan_quantity: @account.subscription.agent_limit
      }
    }
  end

  def chargebee_omni_pre_requisites_setup(create_fch = false, create_fcl = false)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(true)
    Account.any_instance.stubs(:freshchat_account_present?).returns(create_fch)
    Account.any_instance.stubs(:freshcaller_account_present?).returns(create_fcl)
    create_freshchat_account(@account) if create_fch
    create_freshcaller_account(@account) if create_fcl
  end

  def chargebee_omni_pre_requisites_teardown
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:freshchat_account_present?)
    Account.any_instance.unstub(:freshcaller_account_present?)
    @account.freshchat_account&.destroy
    @account.freshcaller_account&.destroy
    @account.reload
  end

  def create_organisation(org_id, org_domain)
    Organisation.stubs(:organisation_account_mapping).returns(true)
    Organisation.create(organisation_id: org_id, domain: org_domain)
  ensure
    Organisation.unstub(:organisation_account_mapping)
  end

  def delete_organisation(org_id)
    OrganisationAccountMapping.find_by_organisation_id(org_id)&.destroy
  end

  def create_organisation_account_mapping(org_id)
    OrganisationAccountMapping.create(account_id: @account.id, organisation_id: org_id)
  end

  def org_freshid_response(account_details = [], metadata = {})
    accounts = []
    accounts = account_details.map do |account|
      {
        id: '181732831288921786',
        organisation_id: account[:organisation_id],
        product_id: account[:product_id],
        domain: account[:domain]
      }
    end
    {
      accounts: accounts,
      total_size: accounts.count,
      page_number: metadata[:page_number],
      page_size: metadata[:page_size],
      has_more: metadata[:has_more]
    }
  end

  def create_sample_account_details(fch_domain, fcl_domain)
    [
      {
        organisation_id: 12_345,
        domain: fcl_domain,
        product_id: '006'
      },
      {
        organisation_id: 12_345,
        domain: fch_domain,
        product_id: '007'
      }
    ]
  end

  def create_sample_freshchat_agent_hash(email)
    {
      id: '2681d294-3460-4f32-b5fb-828958995b5c',
      freshid_uuid: '3081d294-3460-4f32-b5fb-828958995b2c',
      email: email,
      avatar: {
        url: 'https://web.freshchat.com/img/test.png'
      },
      phone: '123456789',
      biography: 'Test biography',
      get_ocr_available: 1,
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      social_profiles: [
        {
          type: 'facebook',
          id: 'test.sample'
        }
      ],
      groups: [
        'string'
      ],
      role_id: 'string',
      skill_id: 'string',
      is_deactivated: false,
      locale: 'en-us',
      availability_status: 'AVAILABLE'
    }
  end

  def sample_freshchat_agents_response(emails)
    {
      agents: emails.map { |email| create_sample_freshchat_agent_hash(email) },
      links: {}
    }
  end

  def create_sample_freshcaller_agent_hash(email)
    id = Faker::Number.number(2)
    {
      id: id.to_s,
      type: 'user',
      attributes: {
        name: Faker::Name.name,
        email: email,
        confirmed: false,
        "email-confirmed": false,
        deleted: false,
        "sip-enabled": false,
        extension: '',
        "extension-enabled": false,
        "bundle-app-id": 6
      },
      relationships: {
        role: {
          data: {
            id: '2',
            type: 'roles'
          }
        }
      }
    }
  end

  def sample_freshcaller_agents_response(emails)
    agents = emails.map { |email| create_sample_freshcaller_agent_hash(email) }
    response = { sucess: true }
    response.stubs(:body).returns({
      data: agents
    }.to_json)
    response.stubs(:code).returns(200)
    response.stubs(:message).returns('Success')
    response.stubs(:headers).returns({})
    response
  end
end
