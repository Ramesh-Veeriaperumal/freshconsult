module Ember
  class RtsController < ApiApplicationController
    include ::RTS::Constants

    before_filter :access_denied, if: :rts_disabled?

    def show
      @item = {
        rts_account_id: @account_additional_settings.rts_account_id,
        url: RTSConfig['end_point'],
        token: generate_jwt_token
      }
      response.api_root_key = :rts
    end

    private

      def load_object
        @account_additional_settings = current_account.account_additional_settings
      end

      def generate_jwt_token
        JWT.encode(payload, @account_additional_settings.rts_account_secret, RTS_JWT_ALGO) if @account_additional_settings.rts_account_secret.present?
      end

      def payload
        {
          accId: @account_additional_settings.rts_account_id,
          userId: current_user.id.to_s,
          exp: jwt_expiry,
          credentials: [{
            resource: '*',
            perms: ['*'],
            expire: Time.now.to_i + 10.hours
          }]
        }
      end

      def jwt_expiry
        Time.now.to_i + 10.hours
      end

      def rts_disabled?
        !Account.current.agent_collision_revamp_enabled?
      end
  end
end
