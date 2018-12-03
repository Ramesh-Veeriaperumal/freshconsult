['marketplace_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module MarketplaceTestHelper
  include MarketplaceHelper

  def marketplace_apps_pattern
    [{
      id: 1,
      display_name: 'Google Plug',
      configs: nil,
      placeholders: {
        ticket_sidebar: {
          url: 'https://dummy.cloudfront.net/app-assets/1/app/template.html',
          icon_url: 'https://dummy.cloudfront.net/app-assets/1/app/logo.png'
        }
      },
      enabled: 1,
      version_id: 3,
      features: ['backend'],
      extension_type: 1
    }]
  end

  def marketplace_apps_agent_oauth
    [{
      id: 1,
      display_name: 'Google Plug',
      configs: nil,
      placeholders: {
        ticket_sidebar: {
          url: 'https://dummy.cloudfront.net/app-assets/1/app/template.html',
          icon_url: 'https://dummy.cloudfront.net/app-assets/1/app/logo.png'
        }
      },
      enabled: 1,
      version_id: 3,
      features: ['backend', 'agent_oauth'],
      extension_type: 1,
      authorize_url: 'http://localhost:3005/product/4/account/1/versions/3/oauth_install?callback=http://localhost.freshpo.com/admin/marketplace/installed_extensions/1/3/oauth_callback&fdcode=Freshdesk+54375eb91740125b26ce9bcf41898699',
      reauthorize_url: 'http://localhost:3005/product/4/account/1/versions/3/oauth_install?callback=http://localhost.freshpo.com/admin/marketplace/installed_extensions/1/3/oauth_callback&edit_oauth=true&installed_extn_id=1&fdcode=Freshdesk+9b27c383b3bbae964d161e76bebfec66'
    }]
  end
  
end
