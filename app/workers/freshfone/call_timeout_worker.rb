module Freshfone
  class CallTimeoutWorker < BaseWorker
    include Freshfone::Endpoints
    include Freshfone::FreshfoneUtil
    include Freshfone::CallsRedisMethods

    sidekiq_options queue: :freshfone_trial_worker, retry: 0,
                    failures: :exhausted

    attr_accessor :params, :current_account, :current_call

    def perform(params)
      Rails.logger.info "Call Timeout Worker:: #{params.inspect}"

      begin
        params.symbolize_keys!
        return if params[:account_id].blank?
        ::Account.reset_current_account
        Sharding.select_shard_of(params[:account_id]) do
          account = ::Account.find params[:account_id]
          raise ActiveRecord::RecordNotFound if account.blank?
          account.make_current

          self.params = params
          self.current_account = account
          self.current_call = current_account.freshfone_calls.find(params[:call_id])
          return if agent_disconnected?
          Rails.logger.info "Disconnect Call from Call Timeout Worker Account:#{params[:account_id]}, Call:#{current_call.id}"
          worker_params = params.except(:call_id).merge(call_ids: [params[:call_id]])
          Freshfone::DisconnectWorker.perform_async(worker_params)
        end
      rescue => e
        Rails.logger.error "Error in Call Timeout Worker for account #{params[:account_id]} for User #{params[:agent]}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        NewRelic::Agent.notice_error(e, {description: "Error in Call Timeout Worker for account #{params[:account_id]} for User #{params[:agent]}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"})
      ensure
        ::Account.reset_current_account
      end
    end

    def agent_disconnected?
      get_voicemail_key(params[:account_id], params[:call_id]).present? ||
        !current_call.can_be_disconnected?(params[:agent])
    end
  end
end