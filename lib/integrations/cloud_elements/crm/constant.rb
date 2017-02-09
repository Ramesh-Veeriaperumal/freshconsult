module Integrations::CloudElements
  module Crm::Constant
    MAPPING_ELEMENTS = [:salesforce_v2, :dynamics_v2]
    OAUTH_ELEMENTS = ["salesforce_v2"]
    NO_METADATA_EVENTS = ["integrated_resource", "link_opportunity", "unlink_opportunity"]
    OAUTH_ERROR = "OAuth Token is nil"
    SALESFORCE_V2 = Integrations::CloudElements::Crm::SalesforceV2::Constant::SALESFORCE_V2
    SALESFORCE_V2_JSON = Integrations::CloudElements::Crm::SalesforceV2::Constant::SALESFORCE_V2_JSON
    DYNAMICS_V2 = Integrations::CloudElements::Crm::DynamicsV2::Constant::DYNAMICS_V2
    DYNAMICS_V2_JSON = Integrations::CloudElements::Crm::DynamicsV2::Constant::DYNAMICS_V2_JSON
    SYNC_FREQUENCY = { "instant" => 30, "hourly" => 60, "daily" => 3600}
    FRONTEND_OBJECTS = {:totalSize => "totalSize", :done => "done", :records => "records", :attributes => "attributes", :type => "type"}

    FRESHDESK_JSON = {
      "element" => { "key" => "freshdeskv2" },
      "configuration" => {
        "username" => "%{api_key}",
        "subdomain" => "%{subdomain}",
        "event.notification.enabled" => "false",
        "event.poller.refresh_interval"=>"1", 
        "event.poller.configuration" => " {\"contacts\": {\"url\": \"/hubs/helpdesk/contacts?where=_updated_since='${date:yyyy-MM-dd'T'HH:mm:ss'Z'}'\",\"idField\": \"id\",\"datesConfiguration\": {\"updatedDateField\": \"updated_at\",\"updatedDateFormat\": \"yyyy-MM-dd'T'HH:mm:ssXXX\",\"UpdatedDateTimezone\": \"%{time_zone}\",\"createdDateField\": \"created_at\",\"createdDateFormat\": \"yyyy-MM-dd'T'HH:mm:ssXXX\",\"createdDateTimezone\": \"%{time_zone}\"}},\"accounts\": {\"url\": \"/hubs/helpdesk/accounts\",\"idField\": \"customer.id\",\"datesConfiguration\": {\"updatedDateField\": \"customer.updated_at\",\"updatedDateFormat\": \"yyyy-MM-dd'T'HH:mm:ssXXX\",\"UpdatedDateTimezone\": \"%{time_zone}\",\"createdDateField\": \"customer.created_at\",\"createdDateFormat\": \"yyyy-MM-dd'T'HH:mm:ssXXX\",\"createdDateTimezone\": \"%{time_zone}\"},\"pageSize\": 2000}}\n"
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

    #Used for rendering the objects in the front end view of CRM requester info section.
    OBJECT_QUERIES = {
      :account_resource => {
        "salesforce_v2" => "Name='%{company}'",
        "dynamics_v2" => "name='%{company}'"
      },
      :contact_resource => {
        "salesforce_v2" => "Email='%{email}'",
        "dynamics_v2" => "emailaddress1='%{email}'"
      },
      :contract_resource => {
        "salesforce_v2" => "AccountId='%{account_id}'&pageSize=5&orderBy=CreatedDate ASC",
        "dynamics_v2" => "customerid='%{account_id}'&pageSize=5&orderBy=modifiedon desc"
      },
      :lead_resource => {
        "salesforce_v2" => "Email='%{email}' AND IsConverted=false",
        "dynamics_v2" => "emailaddress1='%{email}'"
      },
      :opportunity_resource => {
        "salesforce_v2" => "AccountId='%{account_id}' AND IsClosed=false&pageSize=5&orderBy=CloseDate ASC, CreatedDate ASC",
        "dynamics_v2" => "customerid='%{account_id}'AND salesstage!='3'&pageSize=5&orderBy=modifiedon desc"
      },
      :opportunity_id_resource => {
        "salesforce_v2" => "AccountId='%{account_id}' AND Id='%{opportunity_id}'",
        "dynamics_v2" => "customerid='%{account_id}' AND opportunityid='%{opportunity_id}'"
      },
      :order_resource => {
        "salesforce_v2" => "AccountId='%{account_id}'&pageSize=5&orderBy=CreatedDate ASC",
        "dynamics_v2" => "customerid='%{account_id}'&pageSize=5&orderBy=modifiedon desc"
      }
    }

  end
end