module Ember
  class ContactFieldsController < ::ApiContactFieldsController
    # Whenever we change the Structure (add/modify/remove keys), we will have to modify the below constant
    CURRENT_VERSION = 'private-v1'.freeze
    send_etags_along('CONTACT_FIELD_LIST')
  end
end
