# frozen_string_literal: true

module Admin
  class ApiSecurityController < ApiApplicationController
    include HelperConcern
    include Admin::SecurityConstants
    include SecurityConcern

    decorate_views

    def show
      response.api_meta = {}.tap do |meta|
        meta[:current_ip] = request.remote_ip if current_account.whitelisted_ips_enabled?
        if private_api?
          meta[:freshid_migration_in_progress] = @item.freshid_migration_in_progress?
          meta[:freshid_sso_enabled] = @item.freshid_sso_enabled?
        end
      end
    end

    def update
      return unless validate_delegator(@item, cname_params)

      render_errors(@item.errors) unless @item.save
      render_errors(@item.account_configurations.errors) if cname_params[:notification_emails].present? && !@item.account_configuration.save
    end

    private

      def load_object
        @item = current_account
      end

      def validate_params
        cname_params.permit(*WHITELISTED_SECURITY_FIELDS)
        security_validation = validation_klass.new(cname_params, @item, string_request_params?)
        render_custom_errors(security_validation, true) unless security_validation.valid?(action_name.to_sym)
      end

      def sanitize_params
        UPDATE_SECURITY_FIELDS.each do |field|
          safe_send("assign_#{field}_settings") if cname_params.key?(field)
        end
      end

      def constants_class
        'Admin::SecurityConstants'
      end
  end
end
