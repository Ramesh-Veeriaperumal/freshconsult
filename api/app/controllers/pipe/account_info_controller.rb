module Pipe
  class AccountInfoController < ApiApplicationController
    skip_before_filter :check_privilege, :verify_authenticity_token, :check_account_state,
                       :set_time_zone, :check_day_pass_usage, :set_locale, :set_current_account, :validate_filter_params,
                       :check_session_timeout

    def index
      account = Account.find(params[:account_id]).make_current
      @item = {
        status: account.subscription.state,
        plan: account.plan_name,
        features: (account.feature_from_cache + account.features_list).uniq
      }
    ensure
      Account.reset_current_account
    end

    private
    def select_shard(&block)
      Sharding.admin_select_shard_of(params[:account_id]) do
        yield
      end
    end
  end
end