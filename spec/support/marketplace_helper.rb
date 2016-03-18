module MarketplaceHelper

  def extensions
    body =  [{ "name" => "Plug 1",
                 "display_name" => "Plug 1",
                 "description" => "desc",
                 "version_id" => 3,
                 "categories" => ["Agent Productivity"],
                 "cover_art" => "//s3.amazonaws.com/freshapps-images.freshpo.com/3/cover_art/thumb/Screen1.png"
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
              "version_id" => 3,
              "latest_version" => 2,
              "name" => "Plug 1",
              "display_name" => "Plug 1",
              "description" => "desc",
              "install_count" => 2,
              "app_version" => "2.0",
              "account" => "",
              "options" => [1],
              "published_date" => "13 days",
              "instructions" => "",
              "whats_new" => "",
              "cover_art" => "//s3.amazonaws.com/freshapps-images.freshpo.com/3/cover_art/thumb/Screen1.png",
              "categories" => [],
              "screenshots" =>
                [{ 
                  "large"=> "//s3.amazonaws.com/freshapps-images.freshpo.com/3/screenshot/large/Screen2.png",
                  "thumb" => "//s3.amazonaws.com/freshapps-images.freshpo.com/3/screenshot/thumb/Screen2.png"
                }]
            }
    FreshRequest::Response.new(Response.new(body))
  end

  def install_status
    body = { "installed" => false }
    FreshRequest::Response.new(Response.new(body))
  end

  def configs
    body = [{ "name" => "UserName", "label" => "User Name", "description" => "Enter your User Name", 
       "default_value" => "ABCD", "field_type" => 1}]
    FreshRequest::Response.new(Response.new(body))
  end

  def status
    body = { :status => 200 }
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