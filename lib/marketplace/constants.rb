module Marketplace::Constants

  PRODUCT_ID = 1
  DEV_PORTAL_NAME = 'Freshdesk Marketplace'
  ADMIN_PORTAL_NAME = 'Marketplace Admin Portal'

  EXTENSION_TYPES = [ 
    [:plug,  1],    
    [:theme,  2],
    [:app,  3]
  ]

  EXTENSION_TYPE = Hash[*EXTENSION_TYPES.map { |i| [i[0], i[1]] }.flatten]

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

  API_PERMIT_PARAMS = [ :type, :category_id, :in_dev, :name, :update, 
                        :query, :version_id]

end
