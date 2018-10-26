module Channel::V2
  class AccountsController < ApiApplicationController
    skip_before_filter :load_object

    def show
      @item = construct_response
    end

    private

    def construct_response
      {
          id: current_account.id,
          plan: current_account.subscription.subscription_plan.display_name,
          pod: PodConfig['CURRENT_POD']
      }
    end
  end
end