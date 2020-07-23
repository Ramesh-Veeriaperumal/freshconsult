class FreshidRetryWorker < BaseWorker
  sidekiq_options :queue => :freshid_retry_worker, :retry => 0, :failures => :exhausted

  RETRY_LIMIT = 5
  FRESHID_V2_FALLBACK_SUPPORTED_ERROR_CODES = [1, 2, 4, 8, 10, 13, 14].freeze

  def perform(args)
    args.deep_symbolize_keys!
    params = args[:params]
    account_id = params[:account_id]
    Sharding.select_shard_of(account_id) do
      Rails.logger.info "FRESHID RETRY :: Args: #{args.inspect}"
      account = Account.find(account_id).make_current
      loop_counter = params[:loop_counter]
      return unless (FRESHID_V2_FALLBACK_SUPPORTED_ERROR_CODES.include?(args[:error_code]) || params[:retry_now]) && loop_counter <= RETRY_LIMIT

      params[:loop_counter] = loop_counter + 1
      case args[:method]
      when "create_account"
        account.create_freshid_v2_account(account.users.find(params[:user_id]), params[:join_token], params[:organisation_domain], params[:loop_counter])
      when "update_account", "delete_account"
        Freshid::V2::AccountDetailsUpdate.new.perform(params)
      end
    end
  rescue Exception => e
    NewRelic::Agent.notice_error(e)
    Rails.logger.error "FRESHID RETRY EXCEPTION:: Account: #{account_id} :: Exception: #{e.inspect} :: Args: #{args}"
  end
end
