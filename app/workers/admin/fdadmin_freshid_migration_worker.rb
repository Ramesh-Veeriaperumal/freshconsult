class Admin::FdadminFreshidMigrationWorker < BaseWorker
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Freshid::Fdadmin::MigrationHelper
  sidekiq_options queue: :fdadmin_freshid_migration, retry: 0, failures: :exhausted

  def perform(args = {})
    args.symbolize_keys!
    account_id = args[:account_id]
    Sharding.select_shard_of(account_id) do
      @account = Account.find(account_id).make_current
      @doer_email = args[:doer_email]
      @freshid_v2_revert_migration = args[:freshid_v2_revert_migration] || false
      @freshid_v2_migration = args[:freshid_v2_migration] || false
      @org_domain = args[:org_domain] || ''
      Rails.logger.info "Inside Admin::FdadminFreshidMigration Worker :: a=#{@account.try(:id)}, d=#{@account.try(:full_domain)}, args = #{args.inspect}"

      if @freshid_v2_revert_migration
        revert_freshid_v2
      else
        @freshid_v2_migration ? freshid_org_v2_migration : freshid_silent_migration
      end
    end
  rescue StandardError => e
    Rails.logger.error "#{FDADMIN_FRESHID_MIGRATION_WORKER_ERROR} :: freshid_v2_revert_migration = @freshid_v2_revert_migration, freshid_silent_migration = @freshid_silent_migration, e=#{e.inspect}, backtrace=#{e.backtrace}"
  end

  private

  def freshid_silent_migration
    Freshid::Fdadmin::FreshdeskToFreshidMigration.new.freshid_v1_silent_migration(@doer_email)
    Freshid::Fdadmin::FreshidValidateAndFix.new(@doer_email).account_validation
    check_and_enable_freshid(@account)
    @account.account_additional_settings.destroy_freshid_migration(ENABLE_V1_MIGRATION_INPROGRESS) if @account.freshid_enabled?
  rescue StandardError => e
    Rails.logger.error "#{FDADMIN_FRESHID_SILENT_MIGRATION_ERROR} :: a=#{@account.id}, e=#{e.inspect}, backtrace=#{e.backtrace}"
  end

  def revert_freshid_v2
    Freshid::V2::AgentsMigration.new.perform(revert_migration: true)
    Freshid::Account.new(domain: @account.full_domain).destroy
    @account.account_additional_settings.destroy_freshid_migration(DISABLE_V2_MIGRATION_INPROGRESS)
  rescue StandardError => e
    Rails.logger.error "#{FDADMIN_FRESHID_REVERT_AGENTS_ERROR} :: a=#{@account.id}, e=#{e.inspect}, backtrace=#{e.backtrace}"
  end

  def freshid_org_v2_migration
    success = Freshid::Fdadmin::FreshidV1ToV2Migration.new(@doer_email).migrate_account(@account.id, @org_domain)
    Rails.logger.info "Freshid V2 Migration :: freshid_org_v2_migration for a=#{@account.id}, success = #{success}"
    return unless success
    sleep(300)
    Freshid::Fdadmin::FreshidValidateAndFix.new(@doer_email, :freshid_v2).account_validation
    check_and_enable_freshid_v2(@account)
    enable_freshid_sso_sync(@account)
    @account.account_additional_settings.destroy_freshid_migration(ENABLE_V2_MIGRATION_INPROGRESS) if @account.freshid_org_v2_enabled?
  rescue StandardError => e
    Rails.logger.error "#{FDADMIN_FRESHID_V2_MIGRATION_ERROR} :: a=#{@account.id}, e=#{e.inspect}, backtrace=#{e.backtrace}"
  end
end
