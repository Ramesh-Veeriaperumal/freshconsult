module Marketplace::Constants

  PRODUCT_ID = 1
  PRODUCT_NAME = 'freshdesk'
  DEV_PORTAL_NAME = 'Freshdesk Marketplace'
  ADMIN_PORTAL_NAME = 'Marketplace Admin Portal'
  PLG_FILENAME = 'build/index.html'
  DEVELOPED_BY_FRESHDESK = 'freshdesk'
  EXTENSION_SORT_TYPES = ['latest','popular']
  ADDON_ID_PREFIX = 'marketplaceapp_'
  ACCOUNT_ADDON_APP_UNITS = 1
  
  EXTENSION_TYPES = [ 
    [:plug,               1],    
    [:theme,              2],
    [:app,                3],
    [:ni,                 4],
    [:external_app,       5]
  ]

  EXTENSION_TYPE = Hash[*EXTENSION_TYPES.map { |i| [i[0], i[1]] }.flatten]

  APP_TYPES = [ 
    [:regular,               1],    
    [:custom,                2]
  ]

  APP_TYPE = Hash[*APP_TYPES.map { |i| [i[0], i[1]] }.flatten]

  DEFAULT_EXTENSION_TYPES = "#{EXTENSION_TYPE[:plug]},#{EXTENSION_TYPE[:ni]},#{EXTENSION_TYPE[:external_app]}"

  INSTALLED_LIST_EXTENSION_TYPES = "#{EXTENSION_TYPE[:plug]},#{EXTENSION_TYPE[:ni]}"

  FORM_FIELD_TYPES = [
    [:text, 1],
    [:dropdown, 2]
  ]

  FORM_FIELD_TYPE = Hash[*FORM_FIELD_TYPES.map { |i| [i[0], i[1]] }.flatten]

  DISPLAY_PAGE_OPTIONS = [
    [:integrations_list, 0],
    [:ticket_details_page, 1],
    [:contact_details_page, 2]
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

end
