class Admin::Sandbox::MergeWorker < BaseWorker
  include SandboxHelper
  include SandboxConstants

  sidekiq_options queue: :sandbox_merge, retry: 0,  failures: :exhausted

  def perform
    committer = {
      name: User.current.name,
      email: User.current.email
    }
    @account = Account.current
    Sharding.select_shard_of(@account.id) do
      @job = @account.sandbox_job
      @sandbox_account_id = @job.sandbox_account_id
      ::Sync::Workflow.new(@sandbox_account_id, false).move_sandbox_config_to_prod(committer)
      @account.reload.make_current
      @job.reload
      reindex_account(@account, true)
      post_merge_activities
      send_notification(committer)
      delete_sandbox
    end
  rescue StandardError => e
    Rails.logger.error("Sandbox merge Exception in account: #{@account.id}  \n#{e.message}\n#{e.backtrace[0..7].inspect}")
    NewRelic::Agent.notice_error(e, description: "Sandbox merge Error in Account: #{@account.id}")
    @job.update_last_error(e, :error) if @job
    send_error_notification(e, @account)
  end

  private

    def send_notification(committer)
      template_data = JSON.parse(AwsWrapper::S3.read(S3_CONFIG[:bucket], "sandbox/#{@account.id}/#{@sandbox_account_id}_diff_template.json"))
      @account.account_managers.each_slice(20) do |admins|
        data = {
          notifier: 'merge_notifier',
          subject: I18n.t('sandbox.sync_complete'),
          recipients: admins.map(&:email).join(','),
          additional_info: {
            sandbox_url: Account.current.sandbox_domain,
            account_name: @account.name,
            admin_name: committer[:name],
            email_data: parse_email_template_data(template_data['diff'], @account.sandbox_job.additional_data[:failed_records]),
            meta: template_data['meta']
          }
        }
        Admin::SandboxMailer.send_email_to_group(:sandbox_mailer, data[:recipients].split(','), @account, data)
      end
    end

    def post_merge_activities
      account_activities
      update_last_sync_details
      @account.reset_picklist_id
      @account.reset_ticket_source_id
    end

    def delete_sandbox
      @job.mark_as!(:destroy_sandbox)
      ::Admin::Sandbox::DeleteWorker.perform_async(event: SANDBOX_DELETE_EVENTS[:merge])
    end

    def update_last_sync_details
      sync_details = {:last_sync => Time.now.utc, :sync_by => User.current.id}
      (@account.account_additional_settings.additional_settings[:sandbox] ||= {}).merge!(sync_details)
      @account.account_additional_settings.save
    end

    def account_activities
      # Need to move helper. File to data worker and merge worker having same code.
      addition_settings = account_addition_settings_info(@sandbox_account_id)
      @account.time_zone = addition_settings[:time_zone]
      @account.plan_features = addition_settings[:plan_features]
      @account.save
      account_additional_settings = @account.account_additional_settings
      account_additional_settings.supported_languages = addition_settings[:supported_languages]
      @account.account_additional_settings.save
      LaunchParty.new.rollback(account: @account.id, feature: :sandbox_temporary_offset)
    end
end
