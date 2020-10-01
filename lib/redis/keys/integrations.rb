module Redis::Keys::Integrations
  
  INTEGRATIONS_JIRA_NOTIFICATION      = "INTEGRATIONS_JIRA_NOTIFY:%{account_id}:%{local_integratable_id}:%{remote_integratable_id}:%{comment_id}".freeze
  INTEGRATIONS_LOGMEIN                = "INTEGRATIONS_LOGMEIN:%{account_id}:%{ticket_id}".freeze
  INTEGRATIONS_CTI                    = "INTEGRATIONS_CTI:%{account_id}:%{user_id}".freeze
  INTEGRATIONS_CTI_OLD_PHONE          = "INTEGRATIONS_CTI_OLD_PHONE:%{account_id}:%{user_id}".freeze
  SSO_AUTH_REDIRECT_OAUTH             = "AUTH_REDIRECT:%{account_id}:%{user_id}:%{provider}:oauth".freeze
  APPS_AUTH_REDIRECT_OAUTH            = "AUTH_REDIRECT:%{account_id}:%{provider}:oauth".freeze
  APPS_USER_CRED_REDIRECT_OAUTH       = "AUTH_USER_REDIRECT:%{account_id}:%{provider}:%{user_id}:oauth".freeze
  GADGET_VIEWERID_AUTH                = "AUTH_REDIRECT:%{account_id}:google:viewer_id:%{token}".freeze
  GOOGLE_MARKETPLACE_SIGNUP           = "GOOGLE_MARKETPLACE_SIGNUP:%{email}".freeze
  MICROSOFT_OFFICE365_KEYS            = "MICROSOFT_OFFICE365_KEYS".freeze
  DISABLE_DESKTOP_NOTIFICATIONS       = "DESKTOP_NOTIFICATION_DISABLE:%{account_id}:%{user_id}".freeze
  EBAY_APP_THRESHOLD_COUNT            = "EBAY:APP:THRESHOLD:%{date}:%{app_id}".freeze
  EBAY_ACCOUNT_THRESHOLD_COUNT        = "EBAY:ACCOUNT:THRESHOLD:%{date}:%{account_id}:%{ebay_account_id}".freeze
end