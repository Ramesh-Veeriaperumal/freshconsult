module Integrations::CloudElements::Crm
	module DynamicsCrmSync::Constant

		DYNAMICS_CRM_SYNC = {
			"objects"=>{"contact"=>"contact", "account"=>"account"}, 
			"keys"=>["username", "password", "site_url"], 
			"fd_delete_fields"=>["cf_dycontactid", "cf_dyaccountid"],
			"delete_fields"=>{"contact_fields"=>"attributes.new_fdcontact", "contact_fields_types"=>"FDCONTACT", "account_fields"=>"attributes.new_fdaccount", "account_fields_types"=>"FDACCOUNT"}, 
			"existing_companies"=>[{"fd_field"=>"name", "sf_field"=>"attributes.name"}], 
			"existing_contacts"=>[{"fd_field"=>"name", "sf_field"=>"attributes.fullname"}, {"fd_field"=>"email", "sf_field"=>"attributes.emailaddress1"}, {"fd_field"=>"mobile", "sf_field"=>"attributes.mobilephone"}, {"fd_field"=>"phone", "sf_field"=>"attributes.telephone1"}], 
			"validator"=>{
				"String"=>["text", "paragraph"], "Uniqueidentifier"=>[], "Lookup"=>[], "Picklist"=>["dropdown", "dropdown_blank"], 
				"Boolean"=>["checkbox"], "DateTime"=>["date"], "Memo"=>["text", "paragraph"], "Money"=>[], "Integer"=>["number"], "BigInt"=>["number"], 
				"State"=>[], "Status"=>[], "Double"=>[], "Owner"=>[], "Customer"=>[], "EntityName"=>[], "Decimal"=>[]}, 
			"fd_validator"=>{
				"text"=>["String", "Memo"], "email"=>[], "phone_number"=>[], "checkbox"=>["boolean"], "paragraph"=>["String", "Memo"], 
				"dropdown"=>["Picklist"], "dropdown_blank"=>["Picklist"], "number"=>["Integer", "BigInt"], "survey_radio"=>[], 
				"date"=>["DateTime"], "url"=>[]}
		} 

		DYNAMICS_CRM_SYNC_JSON = {
			 "element"=>{"key"=>"dynamicscrmadfs"},
			 "configuration"=>{
			 	"user.username"=>"%{username}", 
			 	"user.password"=>"%{password}", 
			 	"dynamics.tenant"=>"%{site_url}",
			 	"document.tagging"=>false, 
			 	"event.notification.enabled"=>"true", 
			 	"event.vendor.type"=>"polling", 
			 	"event.poller.refresh_interval"=>"1", 
			 	"event.notification.callback.url"=>"%{callback_url}/integrations/sync/crm/event_notification"
			 }, 
			 "name"=>"%{element_name}", "externalAuthentication"=>"initial"
		}.to_json
	end
end