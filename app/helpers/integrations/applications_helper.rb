module Integrations
  module ApplicationsHelper

    include Marketplace::Constants
    include Marketplace::ApiUtil

    def show_edit?(app_name)
      Integrations::Constants::NON_EDITABLE_APPS.exclude?(app_name)
    end

    def is_oauth_app?(extension)
      extension["features"].present? and extension['features'].include?('oauth')
    end

    def is_iframe_app?(extension)
      extension["features"].present? and extension['features'].include?('iframe_settings')
    end

    def is_uninstall_in_progress?(installed_ext)
      installed_ext['state'] == UNINSTALL_IN_PROGRESS
    end

    def generate_mkp_update_button(extension)
      update_params = { "type" => "#{EXTENSION_TYPE[:plug]}", "installation_type" => "update", "display_name" => extension['display_name'] }
      update_url = admin_marketplace_installed_extensions_new_configs_path(extension['extension_id'], extension['version_id'])
      update_button_class = "update"
      if is_oauth_app?(extension)
        update_params["is_oauth_app"] = true
      elsif is_iframe_app?(extension)
        update_params = { "version_id" => extension['version_id'] }
        update_url = admin_marketplace_installed_extensions_reinstall_path(extension['extension_id'])
        update_button_class = "install-btn"
        method = "put"
      end
      link_to t('update'), "#",
        "data-url"=> "#{update_url}?#{update_params.to_query}",
        :class => "btn btn-mini btn-settings #{update_button_class}", "data-developedby"=> extension['account'],
        "data-method" => (method.blank? ? nil : method)
    end

    def generate_mkp_edit_button(extension, installation_details)
      edit_params = { "type" => "#{EXTENSION_TYPE[:plug]}", "installation_type" => "settings", "display_name" => extension['display_name'] }
      edit_url = admin_marketplace_installed_extensions_edit_configs_path(installation_details['extension_id'], installation_details['version_id'])
      edit_button_class = "update"
      if is_iframe_app?(extension)
        edit_url = admin_marketplace_installed_extensions_iframe_configs_path(installation_details['extension_id'], installation_details['version_id'])
        edit_button_class = "update-iframe-settings"
      end
      link_to "<span class='#{font_class('settings1', 16)}'></span>".html_safe, "",
      "data-url"=> "#{edit_url}?#{edit_params.to_query}",
      :class => "btn btn-mini btn-settings #{edit_button_class} tooltip", "data-placement" => "below", "data-original-title" => t('application.tooltip.settings'), "data-developedby"=> extension['account']
    end
  end
end
