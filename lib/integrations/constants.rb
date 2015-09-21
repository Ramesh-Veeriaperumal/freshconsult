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
    :xero => "xero"
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
end
