module Integrations::CloudElements
  module Crm::Constant
    MAPPING_ELEMENTS = [:salesforce_crm_sync]
    OAUTH_ELEMENTS = ["salesforce_crm_sync"]
    OAUTH_ERROR = "OAuth Token is nil"
    SALESFORCE_CRM_SYNC = Integrations::CloudElements::Crm::SalesforceCrmSync::Constant::SALESFORCE_CRM_SYNC
    SALESFORCE_CRM_SYNC_JSON = Integrations::CloudElements::Crm::SalesforceCrmSync::Constant::SALESFORCE_CRM_SYNC_JSON

    FRESHDESK_JSON = {
			"element" => { "key" => "freshdeskv2" },
			"configuration" => {
				"username" => "%{api_key}",
				"subdomain" => "%{subdomain}",
				"event.notification.enabled" => "false"
			},
			"tags" => [],
			"name" => "%{fd_instance_name}"
		}

		INSTANCE_TRANSFORMATION_JSON = {
	    "level" => "instance",
	    "vendorName" => "%{object_name}",
	    "fields" => [],
	    "configuration" => [
	      {
	        "type" => "passThrough",
	        "properties" => {
	          "fromVendor" => true,
	          "toVendor" => true
	        }
	     	}
	    ]
  	}

  	FORMULA_INSTANCE_JSON = {
	    "formula" => {"active" => true},
	    "name" => "%{formula_instance}",
	    "active" => "%{active}",
	    "configuration" => {
	        "element.source" => "%{source}", 
	        "element.target" => "%{target}"
	      }
		}.to_json

  end
end