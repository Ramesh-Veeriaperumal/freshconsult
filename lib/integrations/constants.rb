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
    :salesforce_v2 => "salesforce_v2",
    :dynamics_v2 => "dynamics_v2",
    :office365 => "office365",
    :parent_child_tickets => "parent_child_tickets",
    :link_tickets => "link_tickets",
    :shared_ownership => "shared_ownership"
  }

  DISPLAY_IN_PAGES = { "ticket_show" => 2, "contact_show" => 1, "company_show" => 0 }

  CRM_APPS= [:sugarcrm, :salesforce, :batchbook, :highrise, :nimble, :zohocrm, :capsule_crm, :dynamicscrm, :quickbooks, :freshbooks, :infusionsoft, :freshsales, :salesforce_v2, :dynamics_v2]

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

  ZOHO_CRM_PODS = {:us => "https://crm.zoho.com", :eu => "https://crm.zoho.EU"}

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
    'github' => 'github',
    'salesforce' => 'salesforce',
    'magento' => 'magento',
    'shopify' => 'shopify',
    'slack' => 'slack_v2',
    'infusionsoft' => 'infusionsoft',
    'google_calendar' => 'google_calendar',
    'google_login' => '',
    'google_marketplace_sso' => '',
    'google_contacts' => 'google_contacts',
    'google_gadget' => '',
    'quickbooks' => 'quickbooks',
    'nimble' => 'nimble',
    'surveymonkey' => 'surveymonkey',
    'box' => 'box',
    'mailchimp' => 'mailchimp',
    'constantcontact' => 'constantcontact',
    'surveymonkey' => 'surveymonkey',
    'outlook_contacts' => 'outlook_contacts',
    'salesforce_v2' => 'salesforce_v2',
    'facebook' => '',
    'dynamics_v2' => 'dynamics_v2'
  }.freeze

  EXCLUDE_FROM_APP_CONFIGS_HASH = [:password, :auth_key, :api_key, :app_key, :oauth_token, :refresh_token, :element_token, :auth_token, :session_id, :secret, :cti_ctd_api].freeze

  ZOHO_URL_SUFFIX = '&authtoken='
  MAILCHIMP_URL_SUFFIX = '&apikey='
end