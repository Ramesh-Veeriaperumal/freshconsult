module Marketplace::Constants

  PRODUCT_ID = MarketplaceConfig::TENANT_ID
  PRODUCT_NAME = 'freshdesk'
  DEV_PORTAL_NAME = 'Freshdesk Marketplace'
  ADMIN_PORTAL_NAME = 'Marketplace Admin Portal'
  GALLERY_NAME = 'Marketplace Gallery'
  PLG_FILENAME = '/build/index.html'
  DEVELOPED_BY_FRESHDESK = 'freshdesk'
  EXTENSION_SORT_TYPES = ['latest','popular']
  ADDON_ID_PREFIX = 'marketplaceapp_'
  ACCOUNT_ADDON_APP_UNITS = 1
  IPARAM_IFRAME = 'config/iparams_iframe.html'.freeze
  OAUTH_IPARAM = 'config/oauth_iparams.html'.freeze
  INTERNAL_SERVER_ERROR = 'Internal server error'
  PLATFORM_SOURCE = 'PLATFORM'
  MARKETPLACE_VERSION_MEMBER_KEY = 'MARKETPLACE_APPS_LIST'.freeze
  SECURE_IPARAMS = 'secure_iparams'.freeze
  OAUTH_IPARAMS = 'oauth_iparams'.freeze
  AGENT_OAUTH = 'agent_oauth'.freeze
  
  EXTENSION_TYPES = [
    # Extension Type, Extension Type ID, versionable?
    [:plug,               1, true],    
    [:ni,                 4, false],
    [:external_app,       5, ''],
    [:custom_app,         6,  true]
  ]

  EXTENSION_TYPE = Hash[*EXTENSION_TYPES.map { |i| [i[0], i[1]] }.flatten]
  VERSIONABLE_EXTENSION = EXTENSION_TYPES.map { |i| i[1] if i[2] }

  # TODO: custom type to be removed
  APP_TYPES = [ 
    [:regular,               1],    
    [:custom,                2],
    [:hidden,                3]
  ]

  APP_TYPE = Hash[*APP_TYPES.map { |i| [i[0], i[1]] }.flatten]

  DEFAULT_EXTENSION_TYPES = "#{EXTENSION_TYPE[:plug]},#{EXTENSION_TYPE[:ni]},#{EXTENSION_TYPE[:external_app]}".freeze

  INSTALLED_LIST_EXTENSION_TYPES = "#{EXTENSION_TYPE[:plug]},#{EXTENSION_TYPE[:ni]},#{EXTENSION_TYPE[:custom_app]}".freeze

  INSTALLED_APP_TYPES_V2 = "#{EXTENSION_TYPE[:plug]},#{EXTENSION_TYPE[:custom_app]}".freeze

  FORM_FIELD_TYPES = [
    [:text, 1],
    [:dropdown, 2]
  ]

  FORM_FIELD_TYPE = Hash[*FORM_FIELD_TYPES.map { |i| [i[0], i[1]] }.flatten]

  DISPLAY_PAGE_OPTIONS = [
    [:integrations_list, 0],
    [:ticket_details_page, 1],
    [:contact_details_page, 2],
    [:new_ticket_page_side_bar, 3],
    [:new_outbound_email_page_side_bar, 4]
  ]

  DISPLAY_PAGE = Hash[*DISPLAY_PAGE_OPTIONS.map { |i| [i[0], i[1]] }.flatten]

  EXTENSION_STATUSES = [
    [:disabled, 0],
    [:enabled,  1]
  ]

  EXTENSION_STATUS = Hash[*EXTENSION_STATUSES.map { |i| [i[0], i[1]] }.flatten]

  API_PERMIT_PARAMS = [ :type, :category_id, :display_name, :installation_type,
                        :query, :version_id, :extension_id]
                        
  MKP_ROUTES =[
    [:db, "db"]
  ]

  MKP_ROUTE = Hash[*MKP_ROUTES.map { |i| [i[0], i[1]] }.flatten]

  ADDON_TYPES_ARRAY = [
    [:agent, 1],
    [:account, 2]
  ]

  ADDON_TYPES = Hash[*ADDON_TYPES_ARRAY.map { |i| [i[0], i[1]] }.flatten]

  PLATFORM_VERSIONS_ARRAY = [
    [:v1, '1.0'],
    [:v2, '2.0']
  ]

  PLATFORM_VERSIONS_BY_ID = Hash[*PLATFORM_VERSIONS_ARRAY.map { |i| [i[0], i[1]] }.flatten]
  PLATFORM_ID_BY_VERSION = Hash[*PLATFORM_VERSIONS_ARRAY.map { |i| [i[1], i[0]] }.flatten]

  IFRAME_PERMIT_PARAMS =  { 
                            :user => { "name" => "u_name", "email" => "u_email", "single_access_token" => "u_sat", "time_zone" => "u_tz" },
                            :account => { "domain" => "a_domain", "time_zone" => "a_tz" }
                          }

  IFRAME_USER_PERMIT_PARAMS = Hash[*IFRAME_PERMIT_PARAMS[:user].keys.map { |i| ["user_#{i}", i] }.flatten]

  IFRAME_ACCOUNT_PERMIT_PARAMS = Hash[*IFRAME_PERMIT_PARAMS[:account].keys.map { |i| ["account_#{i}", i] }.flatten]
  
  IFRAME_ALLOWED_ENC_ALGO = [ "RSA1_5", "RSA-OAEP", "RSA-OAEP-256" ]

  IFRAME_DEFAULT_ENC_ALGO = "RSA-OAEP"

  IFRAME_ALLOWED_ENC_TYPE = [ "A128CBC-HS256", "A192CBC-HS384", "A256CBC-HS512", "A128GCM", "A192GCM", "A256GCM" ]

  IFRAME_DEFAULT_ENC_TYPE = "A128CBC-HS256"

  IFRAME_DEFAULT_COMP_ALGO = "DEF"

  UNINSTALL_IN_PROGRESS = 5

end
