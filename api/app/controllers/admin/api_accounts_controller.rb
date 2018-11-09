module Admin
  class ApiAccountsController < ApiApplicationController
    
    include HelperConcern
    
    before_filter :validate_params, :validate_delegator, only: [:cancel]
    
    def cancel
      feedback = {:title => params[cname][:cancellation_feedback],
                  :additional_info => params[cname][:additional_cancellation_feedback]}
      if current_account.paid_account?
        current_account.schedule_account_cancellation_request(feedback)
      else
        current_account.perform_account_cancellation(feedback)
      end
      head 204
    end

    def self.wrap_params
      AccountsConstants::WRAP_PARAMS
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
      
      wrap_parameters(*wrap_params)
  end
end
