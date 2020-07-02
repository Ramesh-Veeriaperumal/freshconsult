module Channel::V2
  class AccountsController < ApiApplicationController

    include ChannelAuthentication

    skip_before_filter :check_privilege, :verify_authenticity_token, :after_load_object, if: :jwt_eligible?
    skip_before_filter :load_object
    before_filter :channel_client_authentication, if: :jwt_eligible?
    before_filter :validate_params, only: [:update_freshchat_domain]

    def show
      @item = construct_response
    end

    def update_freshchat_domain
      freshchat_account = current_account.freshchat_account
      @response = {}
      if freshchat_account.present? && params[:domain].present?
        freshchat_account.domain = params[:domain]
        @response = { message: "Freshchat domain updated successfully - #{freshchat_account.domain}" } if freshchat_account.save!
        render('accounts/update_freshchat_domain', status: 200)
      else
        @response = { message: 'Freshchat account is not present / Freshchat domain is not sent in the params' }
        render('accounts/update_freshchat_domain', status: 400)
      end
    end

    private

    def construct_response
      {
          id: current_account.id,
          plan: current_account.subscription.subscription_plan.display_name,
          pod: PodConfig['CURRENT_POD']
      }
    end

    def validate_params
      params.permit(*Channel::V2::AccountConstants::FRESCHAT_DOMAIN_UPDATE)
    end

    def jwt_eligible?
      request.headers['X-Channel-Auth'].present? && channel_source?(:freshchat)
    end
  end
end