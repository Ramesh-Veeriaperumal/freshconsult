module Marketplace::GalleryConstants
  DEFAULT_AUTH = 'doorkeeper'.freeze
  NATIVE_APP_OAUTH_INSTALL = 'oauth_redirect_install'.freeze
  NATIVE_APP_FORM_INSTALL = 'auth_form_install'.freeze
  NATIVE_APP_DIRECT_INSTALL = 'direct_app_install'.freeze
  AUTH_REDIRECT_APP = ['google_hangout_chat', 'microsoft_teams', 'slack_v2'].freeze
  NATIVE_PAID_APPS = ['salesforce_v2', 'dynamics_v2'].freeze
  MARETPLACE_PAID_NI_APPS_EXPIRY = 1500 # 25 mins expiry for NI paid addonid
  TRIAL_INSTALL = 'trial'.freeze
  TRIAL_DURATION = 30
  BILLING_FAILED = 'FAILED'.freeze
  COMPLETION_STATUS = 200
end
