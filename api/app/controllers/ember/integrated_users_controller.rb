module Ember
  class IntegratedUsersController < ApiApplicationController
    decorate_views

    before_filter :validate_params, only: [:user_credentials_add, :user_credentials_remove]

    def user_credentials_add
      installed_application_id = params[:installed_application_id]
      installed_application = current_account.installed_applications.find(installed_application_id)
      options = { :username => params["username"], :password => params["password"] }
      user_credential = Integrations::UserCredential.add_or_update(installed_application, current_user.id, options)
      head 204
    end

    def user_credentials_remove
      installed_application_id = params[:installed_application_id]
      credentials = current_user.user_credentials.find_by_installed_application_id installed_application_id
      credentials.destroy
      head 204
    end

    private

      def scoper
        return Integrations::UserCredential unless index?
      end

      def load_objects
        @items = Integrations::UserCredential.where(installed_application_id: params[:installed_application_id], user_id: params[:user_id])
      end

      def validate_params
        @filter = IntegratedUserValidation.new(params, nil, true)
        if !@filter.valid?(action_name.to_sym)
          render_errors(@filter.errors, @filter.error_options)
          return
        end

        integrated_user_delegator = IntegratedUserDelegator.new(params)
        render_custom_errors(integrated_user_delegator) unless integrated_user_delegator.valid?
      end

      def validate_filter_params
        params.permit(*IntegratedUserConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
        @filter = IntegratedUserValidation.new(params, nil, true)
        render_errors(@filter.errors, @filter.error_options) unless @filter.valid?(action_name.to_sym)
      end
  end
end
