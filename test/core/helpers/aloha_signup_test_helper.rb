module AlohaSignupTestHelper
  def create_organisation(org_id, org_domain)
    Organisation.create(organisation_id: org_id, domain: org_domain)
  end

  def create_organisation_account_mapping(org_id)
    OrganisationAccountMapping.create(account_id: Account.current.id, organisation_id: org_id)
  end

  def update_bundle_information(bundle_id, bundle_name)
    account = Account.current
    account.account_additional_settings.additional_settings[:bundle_id] = bundle_id
    account.account_additional_settings.additional_settings[:bundle_name] = bundle_name
    account.save!
  end

  def aloha_callback_params
    {
      'bundle_id': '12345',
      'bundle_name': 'support360',
      'account_prov_status': 'True',
      'product_id': '12345',
      'product_name': 'freshchat',
      'status_msg': 'Message',
      'account': {
        'id': '234',
        'domain': 'helo.freshchat.com',
        'description': 'test description',
        'locale': 'en',
        'timezone': 'chennai',
        'alternate_url': 'test.freshchat.com'
      },
      'organisation': {
        'id': '12345'
      },
      'user': {
        'email': 'freshdesk_user@freshworks.com'
      },
      'misc': {
        'userInfoList': [
          {
            'appId': '002e124d-a917-4178-90dd-3d4bc2ea3f56',
            'webchatId': '5e829219-7749-43d5-a9fa-37b1da2236e9'
          }
        ],
        'user': {
          'freshcaller_account_admin_id': 51_725,
          'freshcaller_account_admin_email': 'freshdesk_user@freshworks.com'
        }
      }
    }
  end
end
