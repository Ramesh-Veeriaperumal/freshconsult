module Integrations::GoogleAccountsHelper

    def oauth2_url installed_app=nil
      "#{AppConfig['integrations_url'][Rails.env]}/auth/google_contacts?#{auth_url_params(installed_app)}"
    end

    private
      def auth_url_params installed_app=nil
        url = "origin="
        url << "id%3D#{current_account.id}" if current_account
        url << "%26portal_id%3D#{current_portal.id}" if current_portal
        url << "%26iapp_id%3D#{installed_app.id}" if installed_app
        url
      end
end