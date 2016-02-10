module MarketplaceHelper

  def extensions
    {:extensions =>
      [{ "name" => "Plug 1",
         "description" => "desc",
         "version_id" => 3,
         "categories" => ["Agent Productivity"],
         "cover_art" => "//s3.amazonaws.com/freshapps-images.freshpo.com/3/cover_art/thumb/Screen1.png"
      }]
    }
  end

  def all_categories
    {:categories => [
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
    ]}
  end

  def show_extension
    { "version_id" => 3,
      "instructions" => "",
      "install_count" => 2,
      "version_number" => "2.0",
      "name" => "Plug 1",
      "description" => "desc",
      "account" => "",
      "categories" => [],
      "screenshots" =>
        [{ 
          "large"=> "//s3.amazonaws.com/freshapps-images.freshpo.com/3/screenshot/large/Screen2.png",
          "thumb" => "//s3.amazonaws.com/freshapps-images.freshpo.com/3/screenshot/thumb/Screen2.png"
        }],
      "cover_art" => "//s3.amazonaws.com/freshapps-images.freshpo.com/3/cover_art/thumb/Screen1.png",
      "published_date" => "13 days",
      "changelogs" => [{ "version_id" => 1, "about" => nil}]
    }
  end

  def install_status
    { "installed" => false }
  end

  def configs
    [{ "name" => "UserName", "label" => "User Name", "description" => "Enter your User Name", 
       "default_value" => "ABCD", "field_type" => 1}]
  end

  def status
    { :status => 200 }
  end

  def selecte_params(url_params)
    url_params.select do |key, _| 
      Marketplace::Constants::API_PERMIT_PARAMS.include? key.to_sym
    end
  end
end