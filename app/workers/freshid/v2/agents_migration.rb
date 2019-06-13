class Freshid::V2::AgentsMigration < BaseWorker
  include Freshid::MigrationUtil
  sidekiq_options queue: :freshid_v2_agents_migration, retry: 0,  failures: :exhausted

  def perform(args = {})
    args.symbolize_keys!
    @revert_migration = args[:revert_migration] || false
    @account          = ::Account.current
    fid_migration_in_progress = @account.freshid_migration_in_progress?

    Rails.logger.info "Inside Freshid::V2::AgentsMigration worker :: revert_migration=#{@revert_migration}, a=#{@account.try(:id)}, d=#{@account.try(:full_domain)}, fid_migration_in_progress=#{fid_migration_in_progress}, args = #{args.inspect}"
    return if fid_migration_in_progress

    @account.initiate_freshid_migration
    @revert_migration ? revert_freshid : migrate_agents(args[:organisation], args[:join_token], args[:admin_email])
  rescue Exception => e
    log_migration_error(AGENTS_MIGRATION_WORKER_ERROR, { revert_migration: @revert_migration }, e)
  ensure
    @account.freshid_migration_complete
  end

  private

    def migrate_agents(organisation, join_token, admin_email)
      freshid_integration_enabled = @account.freshid_integration_enabled?
      Rails.logger.info "Inside Freshid::V2::AgentsMigration worker(migrate_agents):: a=#{@account.try(:id)}, freshid_integration_enabled=#{freshid_integration_enabled}"

      return if freshid_integration_enabled
      Rails.logger.info "FRESHID Enabling and Migrating Agents :: a=#{@account.try(:id)}, d=#{@account.try(:full_domain)}"
      account_admin = @account.all_technicians.find_by_email(@account.admin_email) if admin_email.present?
      if account_admin.blank?
        join_token = nil
        account_admin = @account.account_managers.first
      end
      @account.launch_freshid_with_omnibar(true)
      perform_migration_changes
      @account.create_freshid_v2_account(account_admin, join_token, organisation.try([], :domain))
      @account.all_technicians.where("id != #{account_admin.id}").find_each { |user| migrate_user_to_freshid(user) if user.freshid_authorization.blank? }
      @account.enable_fresh_connect
    rescue Exception => e
      log_migration_error(FRESHID_MIGRATE_AGENTS_ERROR, {}, e)
    end

    def revert_freshid
      Rails.logger.info "FRESHID Disabling and Removing Agents :: a=#{@account.try(:id)}, d=#{@account.try(:full_domain)}"
      perform_migration_changes
      freshid_account_params = {
        name: @account.name,
        account_id: @account.id,
        domain: @account.full_domain
      }
      organisation = @account.organisation_from_cache
      Freshid::V2::Models::Account.new(freshid_account_params).destroy(organisation.try(:domain))
      @account.organisation_account_mapping.destroy
      @account.authorizations.where(provider: Freshid::Constants::FRESHID_PROVIDER).destroy_all
    rescue Exception => e
      log_migration_error(FRESHID_REVERT_AGENTS_ERROR, {}, e)
    ensure
      @account.rollback(:freshid_org_v2)
    end
end
