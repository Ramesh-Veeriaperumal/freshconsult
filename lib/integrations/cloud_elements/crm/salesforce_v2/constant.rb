module Integrations::CloudElements::Crm
  module SalesforceV2::Constant

    SALESFORCE_V2 = {
      "objects" => {"contact" => "Contact", "account" =>"Account", "lead" =>"Lead", "opportunity" =>"Opportunity", "contract"=> "Contract", "order"=>"Order"}, # List of Objects whose metadata we need to fetch!
      "element_name" => "salesforce", #Used in Settings Page UI
      "account_name_format" => "Id", #required for fetching the Accounts associated to a contact.
      "opportunity_keys" => {"stage" => "StageName", "choices" => "picklistValues", "value" => "value", "id" => "value"}, # To store opportunity stage choices that will be used to create the New opportunity in the settings page.
      "additional_fields" => {"contact" => {"Address" => "Address", "AccountName" => "Account Name" }, "account" => { "Address" => "Address"}, "lead" => { "Address" => "Address"} }, #Some additional fields that needed to be added to the metadata for our purpose
      "fd_hide_fields"=>["cf_sfcontactid", "cf_sfaccountid", "company_name", "client_manager"], # Freshdesk Custom fields to be removed from the View.
      "default_visibility_fields" => {"contact"=> ["Name"], "account" => ["Name"], "lead" => ["Name"], "opportunity"=> ["Name", "StageName", "CloseDate"], "contract"=> ["ContractNumber","StartDate", "ContractTerm", "Status"], "order"=> ["OrderNumber","EffectiveDate", "TotalAmount"]}, #default view fields
      "default_visibility_labels" => {"contact"=> ["Full Name"], "account"=> ["Account Name"], "lead"=> ["Full Name"], "opportunity"=> ["Name", "Stage", "Close Date"], "contract"=> ["Contract Number","Contract Start Date", "Contract Term", "Status"], "order"=> ["Order Number","Order Start Date", "Order Amount"]}, 
      "delete_fields"=>{"contact_fields"=>["FDCONTACTID__c", "Id", "IsDeleted", "AccountId", "MasterRecordId", "ReportsToId", "OwnerId", "LastModifiedById", "CreatedById", "IsEmailBounced", "JigsawContactId"], 
                        "contact_fields_types"=>["FDCONTACTID", "Contact ID", "Deleted", "Account ID", "Master Record ID", "Reports To ID", "Owner ID", "Last Modified By ID", "Created By ID", "Is Email Bounced", "Jigsaw Contact ID"], 
                        "account_fields"=>["FDACCOUNTID__c", "Id", "IsDeleted", "MasterRecordId", "ParentId", "OwnerId", "CreatedById", "JigsawCompanyId"], 
                        "account_fields_types"=>["FDACCOUNTID", "Account ID", "Deleted", "Master Record ID", "Parent Account ID", "Owner ID", "Created By ID", "Jigsaw Company ID"]}, #Custom fields that should not be synced by the User.
      "existing_companies"=>[{"fd_field"=>"name", "sf_field"=>"Name"}], #default Account sync fields
      "existing_contacts"=>[{"fd_field"=>"name", "sf_field"=>"Name"}, {"fd_field"=>"email", "sf_field"=>"Email"}, {"fd_field"=>"mobile", "sf_field"=>"MobilePhone"}, {"fd_field"=>"phone", "sf_field"=>"Phone"}], #default Contact sync fields
      "validator"=>{"string"=>["text"], "textarea"=>["paragraph"], "boolean"=>["checkbox"], "reference"=>[],
              "phone"=>["phone_number"], "picklist"=>["dropdown", "dropdown_blank"], "multipicklist"=>[], 
              "email"=>["email"], "date"=>["date"], "double"=>["number"], "number"=>["number"], "currency"=>["number"], 
              "encryptedstring"=>["text"], "percent"=>["number"], "url"=>["url"], "id"=>[]}, # Sync: Data type to be shown on the FD dropdown when CRM dropdown is selected
        "fd_validator"=>{"text"=>["string", "encryptedstring"], "email"=>["email"], "phone_number"=>["phone"], 
              "checkbox"=>["boolean"], "paragraph"=>["textarea"], "dropdown"=>["picklist"], "dropdown_blank"=>["picklist"], 
              "number"=>["number", "currency", "percent", "double"], "survey_radio"=>[], "date"=>["date"], "url"=>["url"]} # Vice Versa.
    }

    SALESFORCE_V2_JSON = {
      "element" => {"key" => "sfdc"}, 
      "configuration" => { 
        "oauth.user.refresh_token" => "%{refresh_token}", 
        "oauth.api.key" => "%{api_key}", 
        "oauth.api.secret" => "%{api_secret}", 
        "event.vendor.type" => "polling", 
        "event.notification.enabled" => "false", 
        "event.objects" => "Contact,Account",
        "event.poller.refresh_interval"=> "1"
      },
      "tags" => [], 
      "name" => "%{element_name}",
      "externalAuthentication"=> "initial"
      }.to_json
  
  end

end