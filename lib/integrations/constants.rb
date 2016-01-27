module Integrations::Constants
  APP_NAMES = {
    :capsule_crm => "capsule_crm", 
    :freshbooks => "freshbooks", 
    :harvest => "harvest", 
    :google_contacts => "google_contacts", 
    :jira => "jira",
    :sugarcrm => "sugarcrm", 
    :workflow_max => "workflow_max",
    :salesforce => "salesforce",
    :logmein => "logmein",
    :batchbook => "batchbook",
    :highrise => "highrise",
    :mailchimp => "MailChimp",
    :constantcontact => "ConstantContact",
    :icontact => "iContact",
    :campaignmonitor => "CampaignMonitor",
    :nimble => "nimble",
    :zohocrm => "zohocrm",
    :google_calendar => "google_calendar",
    :surveymonkey => "surveymonkey",
    :dropbox => 'dropbox',
    :shopify => "shopify",
    :seoshop => "seoshop",
    :box => 'box',
    :slack => "slack",
    :quickbooks => "quickbooks",
    :dynamicscrm => "dynamicscrm",
    :xero => "xero",
    :hootsuite => "hootsuite",
    :onedrive => "onedrive",
    :github => "github",
    :ilos => "ilos",
    :magento => "magento"
  }

  APP_CATEGORY_ID_TO_NAME = {
    10 => :custom,
    11 => :crm,
    12 => :invoicing,
    13 => :google
  }
  APP_CATEGORY_NAME_TO_ID = Hash[APP_CATEGORY_ID_TO_NAME.map{|val| [val[1], val[0]]}]

  SYSTEM_ACCOUNT_ID = 0

  CRM_MODULE_TYPES = ["account", "contact", "lead"]

  CRM_INSTANCE_TYPES = { "on_demand" => "On-Demand", "on_premise" => "On-Premise" }

  DYNAMICS_CRM_CONSTANTS = { "rst2_login_url" => "https://login.microsoftonline.com/RST2.srf" }

  GOOGLE_CONTACTS = {"provider" => "google_contacts", "app_name" => "google_contacts"}

  INVOICE_APPS = [APP_NAMES[:quickbooks], APP_NAMES[:freshbooks]]

  CAMPAIGN_APPS = [:mailchimp, :icontact, :constantcontact, :campaignmonitor]

  TIMESHEET_APPS = [APP_NAMES[:freshbooks], APP_NAMES[:harvest], APP_NAMES[:workflow_max], APP_NAMES[:quickbooks]]

  SF_METADATA_CONTACTS = {
  "fields"=> [
    {
      "type"=> "string",
      "vendorPath"=> "Id",
      "vendorDisplayName"=> "Contact ID",
      "vendorRequired"=> true
    },
    {
      "type"=> "boolean",
      "vendorPath"=> "IsDeleted",
      "vendorDisplayName"=> "Deleted",
      "vendorRequired"=> true
    },
    {
      "type"=> "string",
      "vendorPath"=> "MasterRecordId",
      "vendorDisplayName"=> "Master Record ID",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "AccountId",
      "vendorDisplayName"=> "Account ID",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "LastName",
      "vendorDisplayName"=> "Last Name",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "FirstName",
      "vendorDisplayName"=> "First Name",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "Salutation",
      "vendorDisplayName"=> "Salutation",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "Name",
      "vendorDisplayName"=> "Full Name",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "OtherStreet",
      "vendorDisplayName"=> "Other Street",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "OtherCity",
      "vendorDisplayName"=> "Other City",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "OtherState",
      "vendorDisplayName"=> "Other State/Province",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "OtherPostalCode",
      "vendorDisplayName"=> "Other Zip/Postal Code",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "OtherCountry",
      "vendorDisplayName"=> "Other Country",
      "vendorRequired"=> false
    },
    {
      "type"=> "number",
      "vendorPath"=> "OtherLatitude",
      "vendorDisplayName"=> "Other Latitude",
      "vendorRequired"=> false
    },
    {
      "type"=> "number",
      "vendorPath"=> "OtherLongitude",
      "vendorDisplayName"=> "Other Longitude",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "OtherGeocodeAccuracy",
      "vendorDisplayName"=> "Other Geocode Accuracy",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "MailingStreet",
      "vendorDisplayName"=> "Mailing Street",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "MailingCity",
      "vendorDisplayName"=> "Mailing City",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "MailingState",
      "vendorDisplayName"=> "Mailing State/Province",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "MailingPostalCode",
      "vendorDisplayName"=> "Mailing Zip/Postal Code",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "MailingCountry",
      "vendorDisplayName"=> "Mailing Country",
      "vendorRequired"=> false
    },
    {
      "type"=> "number",
      "vendorPath"=> "MailingLatitude",
      "vendorDisplayName"=> "Mailing Latitude",
      "vendorRequired"=> false
    },
    {
      "type"=> "number",
      "vendorPath"=> "MailingLongitude",
      "vendorDisplayName"=> "Mailing Longitude",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "MailingGeocodeAccuracy",
      "vendorDisplayName"=> "Mailing Geocode Accuracy",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "Phone",
      "vendorDisplayName"=> "Business Phone",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "Fax",
      "vendorDisplayName"=> "Business Fax",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "MobilePhone",
      "vendorDisplayName"=> "Mobile Phone",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "HomePhone",
      "vendorDisplayName"=> "Home Phone",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "OtherPhone",
      "vendorDisplayName"=> "Other Phone",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "AssistantPhone",
      "vendorDisplayName"=> "Asst. Phone",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "ReportsToId",
      "vendorDisplayName"=> "Reports To ID",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "Email",
      "vendorDisplayName"=> "Email",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "Title",
      "vendorDisplayName"=> "Title",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "Department",
      "vendorDisplayName"=> "Department",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "AssistantName",
      "vendorDisplayName"=> "Assistant's Name",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "LeadSource",
      "vendorDisplayName"=> "Lead Source",
      "vendorRequired"=> false
    },
    {
      "type"=> "date",
      "vendorPath"=> "Birthdate",
      "mask"=> "yyyy-MM-dd",
      "vendorDisplayName"=> "Birthdate",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "Description",
      "vendorDisplayName"=> "Contact Description",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "OwnerId",
      "vendorDisplayName"=> "Owner ID",
      "vendorRequired"=> true
    },
    {
      "type"=> "date",
      "vendorPath"=> "CreatedDate",
      "mask"=> "yyyy-MM-dd'T'HH=>mm=>ss.SSSZ",
      "vendorDisplayName"=> "Created Date",
      "vendorRequired"=> true
    },
    {
      "type"=> "string",
      "vendorPath"=> "CreatedById",
      "vendorDisplayName"=> "Created By ID",
      "vendorRequired"=> true
    },
    {
      "type"=> "date",
      "vendorPath"=> "LastModifiedDate",
      "mask"=> "yyyy-MM-dd'T'HH=>mm=>ss.SSSZ",
      "vendorDisplayName"=> "Last Modified Date",
      "vendorRequired"=> true
    },
    {
      "type"=> "string",
      "vendorPath"=> "LastModifiedById",
      "vendorDisplayName"=> "Last Modified By ID",
      "vendorRequired"=> true
    },
    {
      "type"=> "date",
      "vendorPath"=> "SystemModstamp",
      "mask"=> "yyyy-MM-dd'T'HH=>mm=>ss.SSSZ",
      "vendorDisplayName"=> "System Modstamp",
      "vendorRequired"=> true
    },
    {
      "type"=> "date",
      "vendorPath"=> "LastActivityDate",
      "mask"=> "yyyy-MM-dd",
      "vendorDisplayName"=> "Last Activity",
      "vendorRequired"=> false
    },
    {
      "type"=> "date",
      "vendorPath"=> "LastCURequestDate",
      "mask"=> "yyyy-MM-dd'T'HH=>mm=>ss.SSSZ",
      "vendorDisplayName"=> "Last Stay-in-Touch Request Date",
      "vendorRequired"=> false
    },
    {
      "type"=> "date",
      "vendorPath"=> "LastCUUpdateDate",
      "mask"=> "yyyy-MM-dd'T'HH=>mm=>ss.SSSZ",
      "vendorDisplayName"=> "Last Stay-in-Touch Save Date",
      "vendorRequired"=> false
    },
    {
      "type"=> "date",
      "vendorPath"=> "LastViewedDate",
      "mask"=> "yyyy-MM-dd'T'HH=>mm=>ss.SSSZ",
      "vendorDisplayName"=> "Last Viewed Date",
      "vendorRequired"=> false
    },
    {
      "type"=> "date",
      "vendorPath"=> "LastReferencedDate",
      "mask"=> "yyyy-MM-dd'T'HH=>mm=>ss.SSSZ",
      "vendorDisplayName"=> "Last Referenced Date",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "EmailBouncedReason",
      "vendorDisplayName"=> "Email Bounced Reason",
      "vendorRequired"=> false
    },
    {
      "type"=> "date",
      "vendorPath"=> "EmailBouncedDate",
      "mask"=> "yyyy-MM-dd'T'HH=>mm=>ss.SSSZ",
      "vendorDisplayName"=> "Email Bounced Date",
      "vendorRequired"=> false
    },
    {
      "type"=> "boolean",
      "vendorPath"=> "IsEmailBounced",
      "vendorDisplayName"=> "Is Email Bounced",
      "vendorRequired"=> true
    },
    {
      "type"=> "string",
      "vendorPath"=> "PhotoUrl",
      "vendorDisplayName"=> "Photo URL",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "Jigsaw",
      "vendorDisplayName"=> "Data.com Key",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "JigsawContactId",
      "vendorDisplayName"=> "Jigsaw Contact ID",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "CleanStatus",
      "vendorDisplayName"=> "Clean Status",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "Level__c",
      "vendorDisplayName"=> "Level",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "Languages__c",
      "vendorDisplayName"=> "Languages",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "Cust_field_1__c",
      "vendorDisplayName"=> "Cust_field_1",
      "vendorRequired"=> false
    },
    {
      "type"=> "date",
      "vendorPath"=> "LastModifiedTIme__c",
      "mask"=> "yyyy-MM-dd'T'HH=>mm=>ss.SSSZ",
      "vendorDisplayName"=> "LastModifiedTIme",
      "vendorRequired"=> false
    },
    {
      "type"=> "string",
      "vendorPath"=> "pl_one__c",
      "vendorDisplayName"=> "pl_one",
      "vendorRequired"=> false
    }
  ]
}

end
