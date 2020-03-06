module AgentAssistHelper
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

  def onboarding_body
    {
      'clntId': 'testaccount',
      'dmn': 'testaccount',
      'eml': @account.admin_email,
      'nm': 'Test Account',
      'phn': '',
      'prtl': 'portal new',
      'wbst': @account.organisation.try(:domain),
      'org_id': @account.organisation.try(:organisation_id),
      'version': 'private'
    }
  end

  def onboard_agent_assist_response
    {
      'clnt': {
        'nm': 'Test Account',
        'clntHsh': 'da023a987928a2ceb6b9bf48aad5ec4b81a93398',
        'dmn': 'testaccount.intfreshbots.com',
        'xtrnlClntId': 'testaccount',
        'prdctHsh': '98b00be11bca86cebae25f50c9b684e5'
      }
    }.to_json
  end

  def agent_assist_bots_response
    {
      "content": [
        {
          "_type": "bot",
          "botVrsnHsh": "4504abfac5e9be103e73e8707f7391f3a21b33a4",
          "botHsh": "58a68557b7c2864881f42fca618bac02214baaaf",
          "vrsnNmbr": 2,
          "intrnlNm": "Basic 2",
          "dscrptn": "Welcome, Hello, Thanks, Sorry, SlashComands",
          "actv": false,
          "crtDt": "2017-07-19T14:14:34Z"
        },
        {
          "_type": "bot",
          "botVrsnHsh": "3d6317177d676f7d5ec0787916750efad0613b70",
          "botHsh": "d3f66088d1fb7c41792cf6157be5677cf57b130a",
          "vrsnNmbr": 1,
          "intrnlNm": "mohan",
          "actv": true,
          "crtDt": "2019-07-11T09:22:47Z"
        }
      ]
    }.to_json
  end
end
