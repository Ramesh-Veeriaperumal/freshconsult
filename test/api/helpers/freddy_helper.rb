module FreddyHelper
  def enable_autofaq
    Account.current.add_feature(:autofaq)
    yield
  ensure
    disable_autofaq
  end

  def disable_autofaq
    Account.current.revoke_feature(:autofaq)
  end

  def params(portal_id, widget_config)
    params = {}
    params['name'] = Faker::Name.name
    params['portal_id'] = portal_id
    params['cortex_id'] = portal_id
    params['widget_config'] = widget_config
    params
  end

  def create_freddy(portal_id, widget_config)
    item = Account.current.freddy_bots.new(params(portal_id, widget_config))
    item.save
    item
  end

  def create_portal(params = {})
    test_portal = FactoryGirl.build(:portal,
                                    name: params[:portal_name] || Faker::Name.name,
                                    portal_url: params[:portal_url] || '',
                                    language: 'en',
                                    forum_category_ids: (params[:forum_category_ids] || ['']),
                                    solution_category_metum_ids: (params[:solution_category_metum_ids] || params[:solution_category_ids] || ['']),
                                    account_id: @account.id,
                                    preferences: {
                                      logo_link: '',
                                      contact_info: '',
                                      header_color: '#252525',
                                      tab_color: '#006063',
                                      bg_color: '#efefef'
                                    })
    test_portal.save(validate: false)
    test_portal
  end

  def freshchat_response
    {
      'app_id': '061ae53e-e0b0-4c4c-8bd9-aaadae1d1007',
      'widget_token': '0c046241-743f-4859-bd62-4de2fed42134'
    }.to_json
  end

  def freshchat_aloha_response
    {
      'product_signup_response': {
        'account': {
          'id': '361428628071297',
          'domain': 'yellowcheck-org.freshpori.com',
          'name': 'yellowcheck-org',
          'description': 'yellowcheck-org.freshpori.com'
        },
        'misc': {
          'defaultApp': 361_428_628_071_297,
          'userInfoList': [
            {
              'appId': '3d00fbcc-dc0d-4d19-86b5-66f13627a092',
              'appKey': '8c0f4078-2f90-4332-9ad1-088164d36b2f',
              'email': 'sarathkumar.subramani+alohaaa1@freshworks.com',
              'appIdReal': 361_428_628_071_297,
              'webchatId': 'd2266807-a8bf-4663-ac5d-d9d698babc9f'
            }
          ]
        }
      }
    }.to_json
  end
end
