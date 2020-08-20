module Admin
  class ApiAccountsController < ApiApplicationController
    include HelperConcern
    include ApiAdminAccountsControllerMethods

    before_filter :validate_params, :validate_delegator, only: [:cancel]
    before_filter :validate_query_params, only: [:download_file]

    def cancel
      feedback = { title: params[cname][:cancellation_feedback], additional_info: params[cname][:additional_cancellation_feedback] }
      if current_account.free_or_active_account?
        current_account.schedule_account_cancellation_request(feedback, current_user)
      else
        current_account.perform_account_cancellation(feedback)
      end
      head 204
    end

    def reactivate
      return head(404) unless cancelled_account? && 
        current_account.kill_scheduled_account_cancellation

      head 204
    end

    def self.wrap_params
      AccountsConstants::WRAP_PARAMS
    end

    def download_file
      s3_url = current_account.safe_send(
        AccountsConstants::DOWNLOAD_TYPE_TO_METHOD_MAP[params[:type].to_sym]
      )
      s3_url.nil? ? head(404) : redirect_to(s3_url, status: 302)
    end

    def support_tickets
      @unresolved_tickets = fetch_unresolved_tickets(current_user.email)
      response.api_root_key = :support_tickets
    end

    private

      def load_object
        @item = current_account
      end

      def scoper
        current_account
      end

      def validate_params
        validate_body_params
      end

      def constants_class
        :AccountsConstants.to_s.freeze
      end

      def cancelled_account?
        current_account.launched?(:downgrade_policy) &&
          current_account.account_cancellation_requested? &&
          !current_account.deletion_scheduled?
      end

      wrap_parameters(*wrap_params)
  end
end
