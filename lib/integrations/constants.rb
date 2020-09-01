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
    :mailchimp => "mailchimp",
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
    :shared_ownership => "shared_ownership",
    :microsoft_teams => "microsoft_teams",
    :google_hangout_chat => "google_hangout_chat",
    :ticket_summary => "ticket_summary",
    :freshworkscrm => "freshworkscrm"
  }

  DISPLAY_IN_PAGES = { 'ticket_show' => 2, 'contact_show' => 1, 'company_show' => 0, 'time_sheet_show' => 3, 'editor_show' => 4 }.freeze

  CRM_APPS= [:sugarcrm, :salesforce, :batchbook, :highrise, :nimble, :zohocrm, :capsule_crm, :dynamicscrm, :quickbooks, :freshbooks, :infusionsoft, :freshsales, :salesforce_v2, :dynamics_v2]

  SERVICE_APPS = %w(github slack_v2 salesforce_v2 dynamics_v2 microsoft_teams google_hangout_chat).freeze

  INTEGRATION_ROUTES = %w(github salesforce magento shopify slack infusionsoft google_calendar google_login google_marketplace_sso google_contacts google_gadget outlook_contacts salesforce_v2 facebook microsoft_teams google_hangout_chat twitter).freeze

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

  NON_EDITABLE_APPS = ["mailchimp", "constantcontact", "nimble", "google_calendar", "box", "onedrive", "microsoft_teams", "google_hangout_chat"]

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
    'box' => 'box',
    'mailchimp' => 'mailchimp',
    'constantcontact' => 'constantcontact',
    'surveymonkey' => 'surveymonkey',
    'outlook_contacts' => 'outlook_contacts',
    'salesforce_v2' => 'salesforce_v2',
    'facebook' => '',
    'dynamics_v2' => 'dynamics_v2',
    'microsoft_teams' => 'microsoft_teams',
    'google_hangout_chat' => 'google_hangout_chat'
  }.freeze

  EXCLUDE_FROM_APP_CONFIGS_HASH = [:password, :auth_key, :api_key, :app_key, :oauth_token, :refresh_token, :element_token, :auth_token, :session_id, :secret, :cti_ctd_api].freeze

  ZOHO_URL_SUFFIX = '&authtoken='
  MAILCHIMP_URL_SUFFIX = '&apikey='

  APPS_DISPLAY_MAPPING = {
    APP_NAMES[:jira] => 4,
    APP_NAMES[:zohocrm] => 6,
    APP_NAMES[:mailchimp].downcase => 2,
    APP_NAMES[:salesforce_v2] => 6,
    APP_NAMES[:harvest] => 8,
    APP_NAMES[:dropbox] => 16,
    APP_NAMES[:box] => 16,
    APP_NAMES[:onedrive] => 16,
    APP_NAMES[:surveymonkey] => 16,
    APP_NAMES[:google_calendar] => 4,
    APP_NAMES[:shopify] => 6,
    APP_NAMES[:salesforce] => 6,
    APP_NAMES[:freshsales] => 6,
    APP_NAMES[:freshworkscrm] => 6
  }.freeze

  ATTACHMENT_APPS = [APP_NAMES[:dropbox],APP_NAMES[:box],APP_NAMES[:onedrive]].freeze

  # Apps that have auth_url and need to set parent href in integrations page.
  ONCLICK_STRATEGY_AUTH_APPS = %w(slack_v2 microsoft_teams google_hangout_chat).freeze

  OAUTH_STRATEGIES_TO_SKIP = %w(github salesforce shopify slack infusionsoft google_oauth2 google_contacts google_gadget_oauth2 outlook_contacts salesforce_v2 microsoft_teams google_hangout_chat).freeze

  FALCON_ENABLED_OAUTH_APPS = [APP_NAMES[:google_calendar], APP_NAMES[:salesforce], APP_NAMES[:salesforce_v2], APP_NAMES[:mailchimp], APP_NAMES[:surveymonkey], APP_NAMES[:outlook_contacts]].freeze

  SKIP_FALCON_RENDER_APPS = [APP_NAMES[:parent_child_tickets], APP_NAMES[:link_tickets], APP_NAMES[:shared_ownership]].freeze
end
