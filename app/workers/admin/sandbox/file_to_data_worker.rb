class Admin::Sandbox::FileToDataWorker < BaseWorker
  include SandboxHelper
  include Sync::Constants
  sidekiq_options queue: :sandbox_file_to_data, retry: 0,  failures: :exhausted

  def perform
    committer = {
      name: User.current.name,
      email: User.current.email
    }
    @account = Account.current
    Rails.logger.info " **** [SANDBOX]  Starting file_to_data for account: #{@account.id} **** "
    Sharding.admin_select_shard_of(@account.id) do
      @job = @account.sandbox_job
      @sandbox_account_id = @job.sandbox_account_id
      User.run_without_current_user do
        pre_migration_activities
      end
      @job.mark_as!(:provision_staging)
      ::Sync::Workflow.new(@sandbox_account_id, false).provision_staging_instance(committer)
      @job.mark_shard_as!(:ok)
      post_data_migration_activities
      @account.make_current # notification email takes current account.
      send_notification(committer)
      @job.mark_as!(:sandbox_complete)
    end
    Rails.logger.info " **** [SANDBOX]  Finished file_to_data for account: #{@account.id} ***** "
  rescue StandardError => e
    Rails.logger.error("Sandbox Exception in account: #{@account.id} \n#{e.message}\n#{e.backtrace[0..7].inspect}")
    NewRelic::Agent.notice_error(e, description: "Sandbox Error in Account: #{@account.id}")
    @job.update_last_error(e, :build_error) if @job
    send_error_notification(e, @account)
  end

  private

    def send_notification(committer)
      @account.account_managers.each_slice(20) do |admins|
        data = {
          notifier: 'notifier',
          subject: I18n.t('sandbox.live'),
          recipients: admins.map(&:email).join(','),
          additional_info: {
            sandbox_url: Account.current.sandbox_domain,
            account_name: @account.name,
            admin_name: committer[:name]
          }
        }
        Admin::SandboxMailer.send_email_to_group(:sandbox_mailer, data[:recipients].split(','), @account, data)
      end
    end

    def destroy_tickets(sandbox_account)
      sandbox_account.tickets.destroy_all
    end

    def post_data_migration_activities
      addition_settings_info = account_addition_settings_info(@account.id)
      Sharding.admin_select_shard_of(@sandbox_account_id) do
        sandbox_account = Account.find(@sandbox_account_id).make_current
        reindex_account(sandbox_account)
        post_account_activities(sandbox_account, addition_settings_info)
        sandbox_account.reset_picklist_id
        sandbox_account.reset_ticket_source_id
        freshid_migration(sandbox_account)
      end
    ensure
      Account.reset_current_account
    end

    def post_account_activities(sandbox_account, addition_settings)
      destroy_tickets(sandbox_account)
      SeedFu::PopulateSeed.populate_sandbox
      sandbox_account.time_zone = addition_settings[:time_zone]
      sandbox_account.plan_features = addition_settings[:plan_features]
      sandbox_account.save
      account_additional_settings = sandbox_account.account_additional_settings
      account_additional_settings.supported_languages = addition_settings[:supported_languages]
      sandbox_account.account_additional_settings.save
    end

    def freshid_migration(sandbox_account)
      if sandbox_account.freshid_enabled?
        Freshid::AgentsMigration.new.perform(revert_migration: true)
        # TODO: Need to stop sending emails
        Freshid::AgentsMigration.new.perform
      elsif sandbox_account.freshid_org_v2_enabled?
        User.run_without_current_user do
          sandbox_account.create_all_users_in_freshid
        end
      end
    end

    def pre_migration_activities
      current_account = Account.current
      Sharding.admin_select_shard_of(@sandbox_account_id) do
        sandbox_account = Account.find(@sandbox_account_id).make_current
        sandbox_account.delete_all_users_in_freshid if sandbox_account.freshid_org_v2_enabled?
      end
    ensure
      Account.reset_current_account
      current_account.make_current
    end
end
