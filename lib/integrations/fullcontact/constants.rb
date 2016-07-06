module Integrations::Fullcontact::Constants

  FC_CONTACT_FIELDS_HASH = { "avatar"=>"Avatar", "full_name"=>"Full Name", "location"=>"Location", "organization"=>"Organization (Primary)", "title"=>"Title (Primary)", "twitter_id"=>"Twitter ID", "aolchat" => "Aol Chat", "facebookchat" => "Facebook Chat", "skype" => "Skype", "twitter_url"=>"Twitter Profile", "linkedin"=>"LinkedIn Profile", "yelp" => "Yelp", "tumblr" => "Tumblr", "reddit" => "Reddit", "plaxo"=>"Plaxo", "pinterest"=>"Pinterest", "quora"=>"Quora", "mySpace"=>"MySpace", "facebook" => "Facebook URL", "googleprofile"=>"Google Profile", "googleplus"=>"Google Plus", "bebo"=>"Bebo", "foursquare"=>"FourSquare" }

  FC_CONTACT_DATA_TYPES = { "Avatar"=>"avatar", "Full Name"=>"text", "Location"=>"text", "Organization (Primary)"=>"company", "Title (Primary)"=>"text", "Twitter ID"=>"twitter", "Aol Chat" => "text", "Facebook Chat" => "text", "Skype" => "text", "Twitter Profile"=>"url", "LinkedIn Profile"=>"url", "Yelp"=>"url", "Tumblr"=>"url", "Reddit"=>"url", "Plaxo"=>"url", "Pinterest"=>"url", "Quora"=>"url", "MySpace"=>"url", "Facebook URL"=>"url", "Google Profile"=>"url", "Google Plus"=>"url", "Bebo"=>"url", "FourSquare"=>"url" }

  FC_CONTACT_SOCIAL_PROFILES = { "Twitter ID" => "social", "Twitter Profile" => "social", "LinkedIn Profile" => "social", "Yelp" => "social", "Tumblr" => "social", "Reddit" => "social", "Plaxo" => "social", "Pinterest" => "social", "Aol Chat" => "social", "Facebook Chat" => "social", "Quora" => "social", "Skype" => "social", "MySpace" => "social", "Google Profile" => "social", "Google Plus" => "social", "Bebo" => "social", "FourSquare" => "social", "Facebook URL" => "social" }

  FC_COMPANY_FIELDS_HASH = { "address" => "Location", "organization_name" => "Organization", "approx_employees" => "Approx Employees", "language_locale" => "Language Locale", "founded" => "Founded", "overview" => "Overview" }

  FC_COMPANY_DATA_TYPES  = {"Location"=>"text", "Organization"=>"text", "Approx Employees"=>"number", "Language Locale"=>"text", "Founded"=>"text", "Overview"=>"text"}

  SELECTED_CONTACT_FIELDS = [{"fc_field"=>"avatar", "fd_field"=>"avatar"}, {"fc_field"=>"full_name", "fd_field"=>"name"}, {"fc_field"=>"location", "fd_field"=>"address"}, {"fc_field"=>"organization", "fd_field"=>"company_name"}, {"fc_field"=>"title", "fd_field"=>"job_title"}, {"fc_field"=>"twitter_id", "fd_field"=>"twitter_id"}]

  SELECTED_COMPANY_FIELDS = [{"fd_field"=>"name", "fc_field"=>"organization_name"}, {"fd_field"=>"description", "fc_field"=>"overview"}]

  FD_CONTACT_TYPES = { 1 => "text", 2 => "text", 6 => "twitter", 7 => "company", 9 => "text", 12 => "text", 13 => "text", 1001 => "text", 1008 => "text", 1009 => "url"}

  FD_COMPANY_TYPES = { 1 => "text", 2 => "text", 3 => "text", 1001 => "text", 1004 => "number", 1008 => "text"}

  FD_CONTACT_FIELD_TYPES = [1, 2, 6, 7, 9, 1001, 1008, 1009]

  FD_COMPANY_FIELD_TYPES = [1, 2, 3, 1001, 1004, 1008]

  FD_VALIDATOR = { 
      "text"=> ["text"],
      "avatar" => ["avatar"],
      "twitter" => ["twitter"],
      "company" => ["company"],
      "url" => ["url"],
      "number" => ["number"]
  }

  FC_VALIDATOR =  { 
      "text"=> ["text"],
      "avatar" => ["avatar"],
      "twitter" => ["twitter"],
      "company" => ["company"],
      "url" => ["url"],
      "number" => ["number"]
    }


end
