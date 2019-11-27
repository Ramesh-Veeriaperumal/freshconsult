module Integrations
  module ApplicationsHelper

    include Marketplace::Constants
    include Marketplace::ApiUtil
    include Marketplace::HelperMethods

    def show_edit?(app_name)
      Integrations::Constants::NON_EDITABLE_APPS.exclude?(app_name)
    end

    def is_iframe_app?(extension)
      extension["features"].present? and extension['features'].include?('iframe_settings')
    end

    def is_uninstall_in_progress?(installed_ext)
      installed_ext['state'] == UNINSTALL_IN_PROGRESS
    end

    def generate_mkp_update_button(extension, installation_details)
      url = "#"
      if(is_oauth_app?(extension))
        if has_oauth_iparams?(extension)
          update_url = admin_marketplace_installed_extensions_new_oauth_iparams_path(extension['extension_id'], extension['version_id'])
          update_params = { "type" => extension['type'], "installation_type" => "settings",
            "display_name" => extension['display_name'], "installed_version" =>  installation_details['version_id']}
          update_button_class = "update"
        else
          update_url = admin_marketplace_installed_extensions_oauth_install_path(extension['extension_id'], extension['version_id'])
          update_params = {}
          update_button_class = "update-oauth"
          url = ""
        end
      else
        update_params = { "type" => extension['type'], "installation_type" => "update", 
                         "display_name" => extension['display_name'],
                         "version_id" => extension['version_id'], "installed_version" => installation_details['version_id'] } 
        update_url = admin_marketplace_installed_extensions_new_configs_path(extension['extension_id'], extension['version_id'])
        update_button_class = "update"

      end
      if is_iframe_app?(extension)
        update_url = admin_marketplace_installed_extensions_reinstall_path(extension['extension_id'])
        update_button_class = "install-btn"
        method = "put"
      end
      link_to t('update'), "#{url}",
        "data-url"=> "#{update_url}?#{update_params.to_query}",
        :class => "btn btn-mini btn-settings #{update_button_class}", "data-developedby"=> extension['account'],
        "data-method" => (method.blank? ? nil : method)
    end

    def generate_mkp_edit_button(extension, installation_details)
      enable_settings = true
      edit_params = { "type" => extension['type'], "installation_type" => "settings", "display_name" => extension['display_name'] }
      edit_url = admin_marketplace_installed_extensions_edit_configs_path(installation_details['extension_id'], installation_details['version_id'])
      edit_button_class = "update"
      if is_oauth_app?(extension)
        if installation_details['configs'].except("access_token", "refresh_token").blank?
          enable_settings = false 
        end 
      elsif is_iframe_app?(extension)
        edit_url = admin_marketplace_installed_extensions_iframe_configs_path(installation_details['extension_id'], installation_details['version_id'])
        edit_button_class = "update-iframe-settings"
      end
      if enable_settings
        link_to "<span class='#{font_class('settings1', 16)}'></span>".html_safe, "", 
        "data-url"=> "#{edit_url}?#{edit_params.to_query}",
        :class => "btn btn-mini btn-settings #{edit_button_class} tooltip", "data-placement" => "below", "data-original-title" => t('application.tooltip.settings'), "data-developedby"=> extension['account']
      end
    end
  end
end
