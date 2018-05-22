class Admin::Sandbox::FileToConfigWorker < BaseWorker
  include SandboxHelper
  include Sync::Constants
  sidekiq_options :queue => :sandbox_file_to_config, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform
    committer = {
        :name  => User.current.name,
        :email => User.current.email
    }
    @account = Account.current
    Rails.logger.info " **** [SANDBOX]  Starting file_to_config for account: #{@account.id} **** "
    message = "Storing mapping table #{Time.now.strftime("%H:%M:%S")}"
    Sharding.admin_select_shard_of(@account.id) do
      @job = @account.sandbox_job
      @sandbox_account_id = @job.sandbox_account_id
      @job.mark_as!(:provision_staging)
      ::Sync::Workflow.new(@sandbox_account_id).provision_staging_instance(committer, message)
      @job.mark_shard_as!(:ok)
      post_data_migration_activities
      @account.make_current # notification email takes current account.
      send_notification(committer)
      @job.mark_as!(:sandbox_complete)
    end
    Rails.logger.info " **** [SANDBOX]  Finished file_to_config for account: #{@account.id} ***** "
    rescue  => e
      Rails.logger.error("Sandbox Exception in account: #{@account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}")
      NewRelic::Agent.notice_error(e, {:description=> "Sandbox Error in Account: #{@account.id}"})
      @job.update_last_error(e) if @job
      send_error_notification(e,@account)
  end

  private

  def send_notification(committer)
    data = {
        recipients: @account.account_managers.map(&:email).join(','),
        additional_info: {
            sandbox_url: DomainMapping.find_by_account_id(@sandbox_account_id).domain,
            account_name: @account.name,
            admin_name: committer[:name]
        }
    }
    Admin::SandboxMailer.safe_send(:sandbox_ready,@account, data)
  end

  def destroy_tickets(sandbox_account)
    sandbox_account.tickets.destroy_all
  end

  def post_data_migration_activities
    Sharding.admin_select_shard_of(@sandbox_account_id) do
      sandbox_account = Account.find(@sandbox_account_id).make_current
      ASSOCIATIONS_TO_REINDEX.each do |assocition_to_index|
        sandbox_account.safe_send(assocition_to_index).find_each do |item|
          item.safe_send(:add_to_es_count) if item.respond_to?(:add_to_es_count, true)
        end
      end
      sandbox_account.safe_send(:enable_searchv2)
      post_account_activities(sandbox_account)
      sandbox_account.safe_send(:enable_freshid) if sandbox_account.freshid_enabled?
    end
  end

  def post_account_activities(sandbox_account)
    destroy_tickets(sandbox_account)
    sandbox_account.time_zone=@account.time_zone
    SeedFu::PopulateSeed.populate_sandbox
    sandbox_account.reputation =  @account.verified? # Verify the sandbox account
    sandbox_account.plan_features = @account.plan_features
    sandbox_account.save
    ## TODO Extend trial period
  end
end