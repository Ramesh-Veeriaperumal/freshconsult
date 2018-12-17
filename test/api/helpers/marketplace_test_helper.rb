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
      authorize_url: 'http://localhost:3005/product/4/account/1/versions/3/oauth_install?fdcode=Freshdesk+081eebbfb4f32661a431f24f64a5e0f4',
      reauthorize_url: 'http://localhost:3005/product/4/account/1/versions/3/oauth_install?fdcode=Freshdesk+081eebbfb4f32661a431f24f64a5e0f4'
    }]
  end
  
end
