class Admin::CloneWorker < BaseWorker
  include Sync::Constants
  sidekiq_options :queue => :clone, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    account_id = args[:account_id]
    @clone_account_id = args[:clone_account_id]
    Sharding.select_shard_of(account_id) do
      @account = Account.find(account_id).make_current
      @account.agents.first.user.make_current
      user = User.current
      committer = {
        name: user.name,
        email: user.email
      }
      @job = @account.account_additional_settings
      @job.mark_as!(:clone_backup_staging)
      pre_migration_activities(committer)
      @job.mark_as!(:clone_sync_from_prod)
      ::Sync::Workflow.new(nil, false, account_id, true).sync_config_from_production(committer)
      @job.mark_as!(:clone_provision_staging)
      ::Sync::Workflow.new(@clone_account_id, false, account_id, true).provision_staging_instance(committer)
      post_data_migration_activities
      @job.mark_as!(:clone_complete)
    end
  rescue  => e
    Rails.logger.error("Clone Exception in account: #{account_id} Clone account: #{@clone_account_id} :: #{e.message} :: #{e.backtrace[0..50]}")
    NewRelic::Agent.notice_error(e, {:description=> "Clone Error in Account: #{account_id}"})
    @job.update_last_error(e, :clone_error)
  ensure
    Account.reset_current_account
    User.reset_current_user
  end

  private

    def destroy_tickets(clone_account)
      clone_account.tickets.destroy_all
    end

    def post_data_migration_activities
      Sharding.admin_select_shard_of(@clone_account_id) do
        clone_account = Account.find(@clone_account_id).make_current
        ASSOCIATIONS_TO_REINDEX.each do |association_to_index|
          clone_account.safe_send(association_to_index).find_each do |item|
            item.safe_send(:add_to_es_count) if item.respond_to?(:add_to_es_count, true)
          end
        end
        clone_account.safe_send(:enable_searchv2)
        post_account_activities(clone_account)
        freshid_migration(clone_account)
      end
    end

    def freshid_migration(clone_account)
      if clone_account.freshid_enabled?
        Freshid::AgentsMigration.new.perform(revert_migration: true)
        # TODO: Need to stop sending emails
        Freshid::AgentsMigration.new.perform
      elsif clone_account.freshid_org_v2_enabled?
        User.run_without_current_user do
          clone_account.create_all_users_in_freshid
        end
      end
    end

    def post_account_activities(clone_account)
      clone_account.time_zone = @account.time_zone
      clone_account.reputation =  @account.verified?
      clone_account.plan_features = @account.plan_features
      clone_account.save
    end

    def pre_migration_activities(committer)
      Sharding.admin_select_shard_of(@clone_account_id) do
        clone_account = Account.find(@clone_account_id).make_current
        branch_name = "#{@clone_account_id}-obsolete"
        ::Sync::Workflow.new(nil, false, @clone_account_id, true, branch_name).sync_config_from_production(committer)
        destroy_tickets(clone_account)
        User.run_without_current_user do
          clone_account.delete_all_users_in_freshid if clone_account.freshid_org_v2_enabled?
        end
      end
      @account.make_current
    end
end
