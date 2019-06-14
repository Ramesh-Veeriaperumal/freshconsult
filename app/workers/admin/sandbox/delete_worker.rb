class Admin::Sandbox::DeleteWorker < BaseWorker
  include MemcacheKeys
  include SandboxConstants

  sidekiq_options queue: :delete_sandbox, retry: 0,  failures: :exhausted

  def perform(args)
    args.symbolize_keys!
    @account = Account.current
    Sharding.select_shard_of(@account.id) do
      @sandbox_job = @account.sandbox_job
      destroy_sandbox_account(@sandbox_job.sandbox_account_id)
      @account.make_current # Reset make current again which was overridden in destroy_sandbox_account
      @account.mark_as!(:production_without_sandbox)
      (@account.account_additional_settings.additional_settings[:sandbox] ||= {})[:status] = 'destroy_complete'
      @account.account_additional_settings.save!
      schedule_sandbox_cleanup(@account.id, @sandbox_job.sandbox_account_id, args[:event])
      @sandbox_job.destroy
    end
  rescue StandardError => error
    send_error_notification(error)
    @sandbox_job.update_last_error(error, :error) if @sandbox_job
    Rails.logger.error("Sandbox delete data error in account: #{@account.id} \n#{error.message}\n#{error.backtrace.join("\n\t")}")
  end

  private

    def send_error_notification(error)
      topic = SNS['sandbox_notification_topic']
      subj = "Delete Sandbox Error in Account: #{@account.id}"
      message = "Delete Sandbox failure in Account id: #{@account.id}, error: #{error.inspect}"
      DevNotification.publish(topic, subj, message.to_json)
    end

    def destroy_sandbox_account(sandbox_account_id)
      Sharding.admin_select_shard_of(sandbox_account_id) do
        sandbox_account = Account.find(sandbox_account_id).make_current
        response = Billing::Subscription.new.cancel_subscription(sandbox_account)
        if response
          sandbox_account.subscription.update_attributes(state: 'suspended')
          AccountCleanup::DeleteAccount.new.perform({})
          raise 'AccountCleanup::DeleteAccount failure' unless sandbox_account.destroyed?
          delete_account_cache_keys(sandbox_account)
        else
          raise 'Sandbox cancel subscription failure in delete sandbox worker'
        end
      end
    ensure
      Account.reset_current_account
    end

    def delete_account_cache_keys(sandbox_account)
      account_domain_keys = [
        format(ACCOUNT_BY_FULL_DOMAIN, full_domain: sandbox_account.full_domain),
        format(SHARD_BY_DOMAIN, domain: sandbox_account.full_domain),
        format(ACCOUNT_MAIN_PORTAL, account_id: sandbox_account.id),
        format(SHARD_BY_ACCOUNT_ID, account_id: sandbox_account.id),
        format(PORTAL_BY_URL, portal_url: sandbox_account.full_domain)
      ]
      account_domain_keys.each do |key|
        MemcacheKeys.delete_from_cache key
      end
    end

    def schedule_sandbox_cleanup(master_account_id, sandbox_account_id, event)
      args = {
        master_account_id: master_account_id,
        sandbox_account_id: sandbox_account_id
      }
      if event == SANDBOX_DELETE_EVENTS[:merge]
        Admin::Sandbox::CleanupWorker.perform_at(1.month.from_now, args)
      else
        Admin::Sandbox::CleanupWorker.perform_async(args)
      end
    end
end
