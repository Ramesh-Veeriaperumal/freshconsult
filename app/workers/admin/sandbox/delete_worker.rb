class Admin::Sandbox::DeleteWorker < BaseWorker
  include MemcacheKeys

  sidekiq_options :queue => :delete_sandbox, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform
    @account = Account.current
    Sharding.select_shard_of(@account.id) do
      @sandbox_job = @account.sandbox_job
      destroy_sandbox_account(@sandbox_job.sandbox_account_id)
      @account.mark_as!(:production_without_sandbox)
      (@account.account_additional_settings.additional_settings[:sandbox] ||= {}).merge!(:status=>"destroy_complete")
      @account.account_additional_settings.save!
      @sandbox_job.destroy
    end
  rescue => error
    send_error_notification(error)
    @sandbox_job.update_last_error(error) if @sandbox_job
    Rails.logger.error("Sandbox delete data error in account: #{@account.id} \n#{error.message}\n#{error.backtrace.join("\n\t")}")
  end

  private
  def send_error_notification(error)
    topic = SNS["sandbox_notification_topic"]
    subj = "Delete Sandbox Error in Account: #{@account.id}"
    message = "Delete Sandbox failure in Account id: #{@account.id}, error: #{error.inspect}"
    DevNotification.publish(topic, subj, message.to_json)
  end


  def destroy_sandbox_account(sandbox_account_id)
    Sharding.admin_select_shard_of(sandbox_account_id) do
      sandbox_account = Account.find(sandbox_account_id).make_current
      response = Billing::Subscription.new.cancel_subscription(sandbox_account)
      if response
        sandbox_account.subscription.update_attributes(:state => "suspended")
        AccountCleanup::DeleteAccount.new.perform({})
        raise "AccountCleanup::DeleteAccount failure" unless sandbox_account.destroyed?
        delete_account_cache_keys(sandbox_account)
      else
        raise "Sandbox cancel subscription failure in delete sandbox worker"
      end
    end
  end

  def delete_account_cache_keys(sandbox_account)
    account_domain_keys = [
        ACCOUNT_BY_FULL_DOMAIN % {:full_domain => sandbox_account.full_domain},
        SHARD_BY_DOMAIN % {:domain => sandbox_account.full_domain},
        ACCOUNT_MAIN_PORTAL % {:account_id => sandbox_account.id},
        SHARD_BY_ACCOUNT_ID % {:account_id => sandbox_account.id},
        PORTAL_BY_URL % {:portal_url => sandbox_account.full_domain}
    ]
    account_domain_keys.each do |key|
      MemcacheKeys.delete_from_cache key
    end
  end
end
