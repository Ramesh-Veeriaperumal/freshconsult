# frozen_string_literal: true

module Admin
  class ApiSecurityController < ApiApplicationController
    decorate_views

    def show
      response.api_meta = {}.tap do |meta|
        meta[:current_ip] = request.remote_ip if current_account.whitelisted_ips_enabled?
        meta[:freshid_migration_in_progress] = @item.freshid_migration_in_progress? if private_api?
      end
    end

    private

      def load_object
        @item = current_account
      end
  end
end
