class Apigee::KVMActionWorker
  include Sidekiq::Worker
  sidekiq_options queue: :apigee_api, retry: 5, backtrace: true, failures: :exhausted

  require 'apigee/kvm'

  def perform(args)
    account_id = args["account_id"]
    return if account_id.blank?
    ::Account.reset_current_account
    Sharding.select_shard_of(account_id) do
      
      account = ::Account.find_by_id account_id
      raise ActiveRecord::RecordNotFound if account.blank?
      account.make_current
      kvm_object = Apigee::KVM.new(args)
      response = kvm_object.safe_send(args["action"], args)
      Rails.logger.info "Apigee Api response #{response.inspect}"
      # clear the cache
      cache_response = kvm_object.safe_send(:clear_kvm_cache, args["domain"])
      Rails.logger.info "Apigee clearing cache response #{cache_response.inspect}"
    end
    rescue => e
      Rails.logger.debug "Something went wrong with the api for account #{account_id},"\
          "argument #{args.inspect}, error => #{e.inspect}"
    ensure
      ::Account.reset_current_account
    end
  end