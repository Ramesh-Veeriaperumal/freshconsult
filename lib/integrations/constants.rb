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
    :magento => "magento",
    :slack_v2 => "slack_v2",
    :infusionsoft => "infusionsoft",
    :pivotal_tracker => "pivotal_tracker",
    :twitter => "twitter",
    :facebook => "facebook",
    :freshsales => "freshsales",
    :fullcontact => "fullcontact",
    :cti => "cti",
    :outlook_contacts => "outlook_contacts",
    :salesforce_v2 => "salesforce_v2"
  }

  DISPLAY_IN_PAGES = { "ticket_show" => 2, "contact_show" => 1, "company_show" => 0, "time_sheet_show" => 3 }

  APPS_DISPLAY_MAPPING = {
    APP_NAMES[:jira] => [DISPLAY_IN_PAGES["ticket_show"]],
    APP_NAMES[:zohocrm] => [DISPLAY_IN_PAGES["ticket_show"],DISPLAY_IN_PAGES["contact_show"]],
    APP_NAMES[:mailchimp] => [DISPLAY_IN_PAGES["contact_show"]],
    APP_NAMES[:salesforce_v2] => [DISPLAY_IN_PAGES["ticket_show"],DISPLAY_IN_PAGES["contact_show"]],
    APP_NAMES[:harvest] => [DISPLAY_IN_PAGES["time_sheet_show"]]
  }

  CRM_APPS= [:sugarcrm, :salesforce, :batchbook, :highrise, :nimble, :zohocrm, :capsule_crm, :dynamicscrm, :quickbooks, :freshbooks, :infusionsoft, :freshsales, :salesforce_v2]

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

  SUCCESS = "success"
  FAILURE = "failure"

  INVOICE_APPS = [APP_NAMES[:quickbooks], APP_NAMES[:freshbooks]]

  CAMPAIGN_APPS = [:mailchimp, :icontact, :constantcontact, :campaignmonitor]

  TIMESHEET_APPS = [APP_NAMES[:freshbooks], APP_NAMES[:harvest], APP_NAMES[:workflow_max], APP_NAMES[:quickbooks]]

  FRESHPLUG = 'freshplug'

  NON_EDITABLE_APPS = ["mailchimp", "constantcontact", "nimble", "google_calendar", "shopify", "box", "onedrive"]

  CONTACTS_SYNC_APPS = [APP_NAMES[:outlook_contacts]]

  CONTACTS_SYNC_ACCOUNTS_LIMIT = 10

  PROVIDER_TO_APPNAME_MAP = {
    "github" => "github",
    "salesforce" => "salesforce",
    "magento" => "magento",
    "shopify" => "shopify",
    "slack" => "slack_v2",
    "infusionsoft" => "infusionsoft",
    "google_calendar" => "google_calendar",
    "google_login" => "",
    "google_marketplace_sso" => "",
    "google_contacts" => "google_contacts",
    "google_gadget" => "",
    "quickbooks" => "quickbooks",
    "nimble" => "nimble",
    "surveymonkey" => "surveymonkey",
    "box" => "box",
    "mailchimp" => "mailchimp",
    "constantcontact" => "constantcontact",
    "surveymonkey" => "surveymonkey",
    "outlook_contacts" => "outlook_contacts",
    "salesforce_v2" => "salesforce_v2",
    "facebook" => ""
  }

end
