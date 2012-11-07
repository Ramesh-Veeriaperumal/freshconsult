module Integrations::Constants
  APP_NAMES = {
    :freshbooks => "freshbooks", 
    :harvest => "harvest", 
    :google_contacts => "google_contacts", 
    :jira => "jira",
    :sugarcrm => "sugarcrm", 
    :workflow_max => "workflow_max",
    :salesforce => "salesforce",
    :logmein => "logmein",
    :batchbook => "batchbook",
    :highrise => "highrise"
  }

  APP_CATEGORY_ID_TO_NAME = {
    10 => :custom,
    11 => :crm,
    12 => :invoicing,
    13 => :google
  }
  APP_CATEGORY_NAME_TO_ID = Hash[APP_CATEGORY_ID_TO_NAME.map{|val| [val[1], val[0]]}]

  SYSTEM_ACCOUNT_ID = 0
end
