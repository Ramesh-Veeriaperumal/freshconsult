module Marketplace::GalleryConstants
  DEFAULT_AUTH = 'doorkeeper'.freeze
  NATIVE_APP_OAUTH_INSTALL = 'oauth_redirect_install'.freeze
  NATIVE_APP_FORM_INSTALL = 'auth_form_install'.freeze
  NATIVE_APP_DIRECT_INSTALL = 'direct_app_install'.freeze
  AUTH_REDIRECT_APP = ['google_hangout_chat', 'microsoft_teams', 'slack_v2'].freeze
end
