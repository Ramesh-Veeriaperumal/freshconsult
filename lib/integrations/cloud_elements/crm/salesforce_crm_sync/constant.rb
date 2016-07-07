module Integrations::CloudElements::Crm
	module SalesforceCrmSync::Constant

		SALESFORCE_CRM_SYNC = {
			"objects"=>{"contact"=>"Contact", "account"=>"Account"}, 
			"fd_hide_fields"=>["cf_sfcontactid", "cf_sfaccountid"],
			"delete_fields"=>{"contact_fields"=>"FDCONTACTID__c", "contact_fields_types"=>"FDCONTACTID", "account_fields"=>"FDACCOUNTID__c", "account_fields_types"=>"FDACCOUNTID"},
			"existing_companies"=>[{"fd_field"=>"name", "sf_field"=>"Name"}], 
			"existing_contacts"=>[{"fd_field"=>"name", "sf_field"=>"Name"}, {"fd_field"=>"email", "sf_field"=>"Email"}, {"fd_field"=>"mobile", "sf_field"=>"MobilePhone"}, {"fd_field"=>"phone", "sf_field"=>"Phone"}], 
			"validator"=>{"string"=>["text"], "textarea"=>["paragraph"], "boolean"=>["checkbox"], "reference"=>[],
						  "phone"=>["phone_number"], "picklist"=>["dropdown", "dropdown_blank"], "multipicklist"=>["dropdown", "dropdown_blank"], 
						  "email"=>["email"], "date"=>["date"], "double"=>["number"], "currency"=>["number"], "encryptedstring"=>["text"], "percent"=>["number"], 
						  "url"=>["url"], "id"=>[]}, "fd_validator"=>{"text"=>["string", "encryptedstring"], "email"=>["email"], "phone_number"=>["phone"], 
						  "checkbox"=>["boolean"], "paragraph"=>["textarea"], "dropdown"=>["picklist", "multipicklist"], "dropdown_blank"=>["picklist", "multipicklist"], 
						  "number"=>["number", "currency", "percent"], "survey_radio"=>[], "date"=>["date"], "url"=>["url"]}
		}

		SALESFORCE_CRM_SYNC_JSON = {
	  	"element" => {"key" => "sfdc"}, 
			"configuration" => { 
		    "oauth.user.refresh_token" => "%{refresh_token}", 
		    "oauth.api.key" => "%{api_key}", 
		    "oauth.api.secret" => "%{api_secret}", 
		    "event.vendor.type" => "polling", 
		    "event.notification.enabled" => "true", 
		    "event.objects" => "Contact,Account",
		    "event.poller.refresh_interval"=> "1",
		    "event.notification.callback.url"=> "%{callback_url}/integrations/sync/crm/event_notification"
	    },
	    "tags" => [], 
	    "name" => "%{element_name}",
	    "externalAuthentication"=> "initial"
	  	}.to_json
  
	end

end