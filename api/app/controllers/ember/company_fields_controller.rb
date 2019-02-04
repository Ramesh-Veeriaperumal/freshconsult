module Ember
  class CompanyFieldsController < ::ApiCompanyFieldsController
    # Whenever we change the Structure (add/modify/remove keys), we will have to modify the below constant
    CURRENT_VERSION = 'private-v2'.freeze
    send_etags_along(CompanyField::VERSION_MEMBER_KEY)
  end
end
