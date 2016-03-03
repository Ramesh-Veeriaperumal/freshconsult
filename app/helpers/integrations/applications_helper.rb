module Integrations
  module ApplicationsHelper

    def show_edit?(app_name)
      Integrations::Constants::NON_EDITABLE_APPS.exclude?(app_name)
    end
  end
end
