module MarketplaceHelper

  def extensions
    body =  [{   
                 "id" => 1,
                 "name" => "google_plug",
                 "display_name" => "Google Plug",
                 "description" => "desc",
                 "cover_art" => "//s3.amazonaws.com/freshapps-images.freshpo.com/3/cover_art/thumb/Screen1.png",
                 "categories" => ["Agent Productivity"],
                 "type" => 1
              }]
    FreshRequest::Response.new(Response.new(body))

  end

  def all_categories
    body = [
            { "id" => 1, "name" => "Agent Productivity" },
            { "id" => 2, "name" => "Chat" },
            { "id" => 3, "name" => "CRM" },
            { "id" => 4, "name" => "E-Commerce" },
           	{ "id" => 5, "name" => "Email Marketing" },
            { "id" => 6, "name" => "Issue Tracking" },
            { "id" => 7, "name" => "IT & Administration" },
            { "id" => 8, "name" => "Knowledge" },
            { "id" => 9, "name" => "Project Management" },
            { "id" => 10, "name" => "Reports" },
            { "id" => 11, "name" => "Social Media" },
            { "id" => 12, "name" => "Surveys & Feedback" },
            { "id" => 13, "name" => "Telephony & SMS" },
            { "id" => 14, "name" => "Time Tracking" }
          ]
    FreshRequest::Response.new(Response.new(body))
  end

  def request_with_error_response
    FreshRequest::Response.new(Response.new(nil, 503))
  end

  def extension_details
    body = { 
              "extension_id" => 1,
              "type" => "1",  
              "account" => "Freshdesk",            
              "name" => "Plug 1",
              "display_name" => "Google Plug",
              "description" => "desc",
              "instructions" => "",
              "cover_art" => 
                { "thumb" => "//s3.amazonaws.com/freshapps-images.freshpo.com/3/cover_art/thumb/Screen1.png",
                  "thumb2x" => "//s3.amazonaws.com/freshapps-images.freshpo.com/3/cover_art/thumb2x/Screen1.png"
                },
              "screenshots" =>
                [{ 
                  "thumb" => "//s3.amazonaws.com/freshapps-images.freshpo.com/3/screenshot/thumb/Screen2.png",
                  "thumb2x" => "//s3.amazonaws.com/freshapps-images.freshpo.com/3/screenshot/thumb2x/Screen2.png",
                  "large"=> "//s3.amazonaws.com/freshapps-images.freshpo.com/3/screenshot/large/Screen2.png",
                  "large2x"=> "//s3.amazonaws.com/freshapps-images.freshpo.com/3/screenshot/large2x/Screen2.png"
                }],
              "categories" => [],
              "contact_details" => {
                  "support_email" => "support@freshdesk.com",
                  "support_url" => "https://support.freshdesk.com"
                },
              "options" => [1],
              "published_date" => "13 days",              
              "version_id" => 3,
              "app_version" => "2.0",
              "whats_new" => "",
              "page_options" => [1]
            }
    FreshRequest::Response.new(Response.new(body))
  end

  def install_status
    body = { 'installed' => false }
    FreshRequest::Response.new(Response.new(body))
  end

  def auto_suggestion
    body = [{ 'suggest_term' => 'Google Plug', 'extension_id' => 1 }]
    FreshRequest::Response.new(Response.new(body))
  end

  def ext_configs
    body = [
        { 
          "name" => "UserName", "label" => "User Name", "description" => "Enter your User Name", 
          "default_value" => "ABCD", "field_type" => 1
        },
        {
          "name" => "Country", "label" => "Country", "description" => "Enter your Country", 
          "default_value" => ["US", "UK", "IN"], "field_type" => 2
        }
      ]
    FreshRequest::Response.new(Response.new(body))
  end

  def account_configs
    body = { "UserName" => "User's Name", "Country" => "IN"}
    FreshRequest::Response.new(Response.new(body))
  end

  def account_configurations
    [
      { 
        "name" => "UserName", "label" => "User Name", "description" => "Enter your User Name", 
        "default_value" => "User's Name", "field_type" => 1
      },
      {
        "name" => "Country", "label" => "Country", "description" => "Enter your Country", 
        "default_value" => ["IN", "US", "UK"], "field_type" => 2
      }
    ]
  end

  def success_response
    body = " "
    FreshRequest::Response.new(Response.new(body))
  end

  def custom_apps
    body = [{
      'id' => 1,
      'name' => 'google_plug',
      'display_name' => 'Google Plug',
      'description' => 'desc',
      'cover_art' => { 'thumb' => 'https://d3h0owdjgzys62.cloudfront.net/images/custom_apps/cover_art/thumb/no_icon.png', 'thumb2x' => 'https://d3h0owdjgzys62.cloudfront.net/images/custom_apps/cover_art/thumb2x/no_icon.png' },
      'categories' => ['Agent Productivity'],
      'type' => 1,
      'install_count' => 0,
      'options' => nil,
      'overview' => 'Auto timer app with timer deactivation on transition',
      'pricing' => false,
      'published_at' => nil
    }]
    FreshRequest::Response.new(Response.new(body))
  end

  def selecte_params(url_params)
    url_params.select do |key, _| 
      Marketplace::Constants::API_PERMIT_PARAMS.include? key.to_sym
    end
  end

  def oauth_handshake_response
    body = { redirect_url: "http://localhost:3005/product/4/account/1/versions/2/oauth_install?fdcode=Freshdesk+3ae07484ef166b45ad830f480b88f6ff&callback=http://localhost.freshpo.com/admin/marketplace/installed_extensions/1/2/oauth_callback"}
    FreshRequest::Response.new(Response.new(body))
  end

  def extension_details_v2
    body = {
      'extension_id' => 1,
      'type' => 1,
      'app_type' => 1,
      'account' => 'Freshdesk',
      'name' => 'google_plug',
      'display_name' => 'Google Plug',
      'description' => 'Dummy Desription',
      'instructions' => nil,
      'cover_art' => {
        'thumb' => 'https://dummy.cloudfront.net/images/04/live_cover_art/thumb/40.png',
        'thumb2x' => 'https://dummy.cloudfront.net/images/04/live_cover_art/thumb2x/40.png'
      },
      'screenshots' => [
        {
          'large' => 'https://dummy.cloudfront.net/images/04/live_screenshot/large/1360x850_Hangouts.png',
          'large2x' => 'https://dummy.cloudfront.net/images/04/live_screenshot/large2x/1360x850_Hangouts.png'
        }
      ],
      'categories' => [
        {
          'id' => 7,
          'name' => 'Google Apps'
        }
      ],
      'contact_details' => {
        'support_email' => 'support@freshdesk.com',
        'support_url' => 'https://support.freshdesk.com'
      },
      'options' => nil,
      'published_date' => 'over 1 year',
      'addon' => nil,
      'platform_details' => {
        '1.0' => [1],
        '2.0' => [3]
      },
      'version_id' => 3,
      'placeholders' => {
        'ticket_sidebar' => {
          'url' => 'https://dummy.cloudfront.net/app-assets/1/app/template.html',
          'icon_url' => 'https://dummy.cloudfront.net/app-assets/1/app/logo.png'
        }
      },
      'features' => ['backend'],
      'events' => { },
      'has_config' => false,
      'app_version' => '3.0',
      'whats_new' => 'Updated to use the latest Google script'
    }
    FreshRequest::Response.new(Response.new(body))
  end

  def extension_details_v2_with_addons
    body = {
      'extension_id' => 1,
      'type' => 1,
      'app_type' => 1,
      'account' => 'Freshdesk',
      'name' => 'google_plug',
      'display_name' => 'Google Plug',
      'description' => 'Dummy Desription',
      'instructions' => nil,
      'cover_art' => {
        'thumb' => 'https://dummy.cloudfront.net/images/04/live_cover_art/thumb/40.png',
        'thumb2x' => 'https://dummy.cloudfront.net/images/04/live_cover_art/thumb2x/40.png'
      },
      'screenshots' => [
        {
          'large' => 'https://dummy.cloudfront.net/images/04/live_screenshot/large/1360x850_Hangouts.png',
          'large2x' => 'https://dummy.cloudfront.net/images/04/live_screenshot/large2x/1360x850_Hangouts.png'
        }
      ],
      'categories' => [
        {
          'id' => 7,
          'name' => 'Google Apps'
        }
      ],
      'contact_details' => {
        'support_email' => 'support@freshdesk.com',
        'support_url' => 'https://support.freshdesk.com'
      },
      'options' => nil,
      'published_date' => 'over 1 year',
      'addons' => [
        {
          'currency_code' => 'USD',
          'trial_period' => 10,
          'price' => '10.0',
          'addon_id' => 1
        }
      ],
      'platform_details' => {
        '1.0' => [1],
        '2.0' => [3]
      },
      'version_id' => 3,
      'placeholders' => {
        'ticket_sidebar' => {
          'url' => 'https://dummy.cloudfront.net/app-assets/1/app/template.html',
          'icon_url' => 'https://dummy.cloudfront.net/app-assets/1/app/logo.png'
        }
      },
      'features' => ['backend'],
      'events' => { },
      'has_config' => false,
      'app_version' => '3.0',
      'whats_new' => 'Updated to use the latest Google script'
    }
    FreshRequest::Response.new(Response.new(body))
  end

   def extension_details_v2_agent_oauth
    body = {
      'extension_id' => 1,
      'type' => 1,
      'app_type' => 1,
      'account' => 'Freshdesk',
      'name' => 'google_plug',
      'display_name' => 'Google Plug',
      'description' => 'Dummy Desription',
      'instructions' => nil,
      'cover_art' => {
        'thumb' => 'https://dummy.cloudfront.net/images/04/live_cover_art/thumb/40.png',
        'thumb2x' => 'https://dummy.cloudfront.net/images/04/live_cover_art/thumb2x/40.png'
      },
      'screenshots' => [
        {
          'large' => 'https://dummy.cloudfront.net/images/04/live_screenshot/large/1360x850_Hangouts.png',
          'large2x' => 'https://dummy.cloudfront.net/images/04/live_screenshot/large2x/1360x850_Hangouts.png'
        }
      ],
      'categories' => [
        {
          'id' => 7,
          'name' => 'Google Apps'
        }
      ],
      'contact_details' => {
        'support_email' => 'support@freshdesk.com',
        'support_url' => 'https://support.freshdesk.com'
      },
      'options' => nil,
      'published_date' => 'over 1 year',
      'addon' => nil,
      'platform_details' => {
        '1.0' => [1],
        '2.0' => [3]
      },
      'version_id' => 3,
      'placeholders' => {
        'ticket_sidebar' => {
          'url' => 'https://dummy.cloudfront.net/app-assets/1/app/template.html',
          'icon_url' => 'https://dummy.cloudfront.net/app-assets/1/app/logo.png'
        }
      },
      'features' => ['backend', 'agent_oauth'],
      'events' => { },
      'has_config' => false,
      'app_version' => '3.0',
      'whats_new' => 'Updated to use the latest Google script'
    }
    FreshRequest::Response.new(Response.new(body))
  end

  def installed_extensions_v2
    body =  [{   
              'installed_extension_id' => 1,
              'extension_id' => 1,
              'version_id' => 3,
              'enabled' => 1,
              'configs' => nil
            }]
    FreshRequest::Response.new(Response.new(body))
  end

  class Response
    attr_reader :body, :status, :response_headers

    def initialize(body, status = 200)
      @body = body
      @status = status
      @response_headers = {}
    end
  end
end