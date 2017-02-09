module Integrations::CloudElements::Crm
  module DynamicsV2::Constant

    DYNAMICS_V2 = {
      "objects"=>{"contact"=>"contact", "account"=>"account", "lead" =>"lead", "opportunity" =>"opportunity", "contract"=> "contract", "order"=>"salesorder"}, # List of Objects whose metadata we need to fetch!
      "element_name" => "dynamics", #Used in Settings Page UI
      "account_name_format" => "accountid", #required for fetching the Accounts associated to a contact.
      "opportunity_keys" => {"stage" => "attributes.salesstage", "choices" => "choices", "value" => "extendedValue", "id" => "value"},# To store opportunity stage choices that will be used to create the New opportunity in the settings page.
      "keys"=>["username", "password", "domain"], #For rendering a settings page to get the basic auth of the user.
      "additional_fields" => {"contact"=>{"AccountName" => "Account Name" }}, # No need to handle address in Dynamics as address is a seperate field.
      "fd_hide_fields"=>["cf_dycontactid", "cf_dyaccountid"],
      "default_visibility_fields" => {"contact"=> ["attributes.fullname"], "account" => ["attributes.name"], "lead"=> ["attributes.fullname"], "opportunity"=> ["attributes.name", "attributes.salesstage", "attributes.estimatedclosedate", "attributes.estimatedvalue"], "contract"=> ["attributes.title","attributes.contractnumber","attributes.activeon", "attributes.expireson"], "order"=> ["attributes.name","attributes.ordernumber","attributes.createdon", "attributes.totalamount"]}, #default view fields
      "default_visibility_labels" => {"contact"=> ["Full Name"], "account"=> ["Account Name"], "lead"=> ["Name"], "opportunity"=> ["Topic", "Sales Stage", "Est. Close Date", "Est. Revenue"], "contract"=> ["Contract Name","Contract ID","Contract Start Date", "Contract End Date"], "order"=> ["Name","Order ID","Created On", "Total Amount"]}, #default view labels
      "delete_fields"=>{"contact_fields"=>["attributes.new_fdcontact"], "contact_fields_types"=>["FDCONTACT"], "account_fields"=>["attributes.new_fdaccount"], "account_fields_types"=>["FDACCOUNT"]}, #Custom fields that should not be synced by the User.
      "existing_companies"=>[{"fd_field"=>"name", "sf_field"=>"attributes.name"}], #default Account sync fields
      "existing_contacts"=>[{"fd_field"=>"name", "sf_field"=>"attributes.fullname"}, {"fd_field"=>"email", "sf_field"=>"attributes.emailaddress1"}, {"fd_field"=>"mobile", "sf_field"=>"attributes.mobilephone"}, {"fd_field"=>"phone", "sf_field"=>"attributes.telephone1"}], #default Contact sync fields
      "validator"=>{
        "String"=>["text", "paragraph"], "Uniqueidentifier"=>[], "Lookup"=>[], "Picklist"=>[], 
        "Boolean"=>["checkbox"], "DateTime"=>["date"], "Memo"=>["text", "paragraph"], "Money"=>[], "Integer"=>["number"], "BigInt"=>["number"], 
        "State"=>[], "Status"=>[], "Double"=>["number"], "Owner"=>[], "Customer"=>[], "EntityName"=>[], "Decimal"=>["number"]}, # Sync: Data type to be shown on the FD dropdown when CRM dropdown is selected
      "fd_validator"=>{
        "text"=>["String", "Memo"], "email"=>[], "phone_number"=>[], "checkbox"=>["boolean"], "paragraph"=>["String", "Memo"], 
        "dropdown"=>[], "dropdown_blank"=>[], "number"=>["Integer", "BigInt", "Decimal", "Double"], "survey_radio"=>[], 
        "date"=>["DateTime"], "url"=>[]} # Vice Versa.
    }

    DYNAMICS_V2_JSON = {
      "element"=>{"key"=>"dynamicscrmadfs"},
      "configuration"=>{
        "user.username"=>"%{username}", 
        "user.password"=>"%{password}", 
        "dynamics.tenant"=>"%{domain}",
        "document.tagging"=>false, 
        "event.notification.enabled"=>"false", 
        "event.vendor.type"=>"polling", 
        "event.poller.refresh_interval"=>"60",
        "event.poller.configuration"=> "\n{\n  \"accounts\": {\n    \"url\": \"/hubs/crm/accounts?where=fetchChanges='true'\",\n    \"idField\": \"id\",\n    \"datesConfiguration\": {\n      \"updatedDateField\": \"attributes.modifiedon\",\n      \"updatedDateFormat\": \"milliseconds\",\n      \"createdDateField\": \"attributes.createdon\",\n      \"createdDateFormat\": \"milliseconds\"\n    }\n  },\n  \"contacts\": {\n    \"url\": \"/hubs/crm/contacts?where=fetchChanges='true'\",\n    \"idField\": \"id\",\n    \"datesConfiguration\": {\n      \"updatedDateField\": \"attributes.modifiedon\",\n      \"updatedDateFormat\": \"milliseconds\",\n      \"createdDateField\": \"attributes.createdon\",\n      \"createdDateFormat\": \"milliseconds\"\n    }\n  }}"
      }, 
      "name"=>"%{element_name}", "externalAuthentication"=>"initial"
    }.to_json
  end
end