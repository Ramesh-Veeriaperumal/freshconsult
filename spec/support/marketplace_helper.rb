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
    body = { "installed" => false }
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

  def auto_suggestion
    body = [{ suggest_term: "Google Plug", extension_id: 1 }]
    FreshRequest::Response.new(Response.new(body))
  end

  def selecte_params(url_params)
    url_params.select do |key, _| 
      Marketplace::Constants::API_PERMIT_PARAMS.include? key.to_sym
    end
  end

  class Response
    attr_reader :body, :status, :response_headers

    def initialize(body)
      @body = body
      @status = 200
      @response_headers = {}
    end
  end
end