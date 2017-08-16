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
  
end
