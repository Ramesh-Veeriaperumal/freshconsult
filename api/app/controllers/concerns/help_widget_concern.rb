module HelpWidgetConcern
  extend ActiveSupport::Concern

  private

    def assign_default_settings(settings_param, product_id)
      portal = get_portal(product_id)
      settings = HelpWidget::DEFAULT_SETTINGS.dup
      assign_portal_defaults(portal, settings) if portal.present?
      settings[:components].merge!(settings_param[:components].symbolize_keys)
      settings
    end

    def get_portal(product_id)
      current_account.portals.find_by_product_id(product_id)
    end

    def assign_portal_defaults(portal, settings)
      settings[:message] = I18n.t('help_widget.name', name: portal.name) if portal.name
      settings[:appearance][:button_color] = portal.preferences[:tab_color] if portal.preferences[:tab_color]
    end
end
