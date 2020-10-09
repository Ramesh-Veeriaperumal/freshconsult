# frozen_string_literal: true

module Migration
  class EnableOmniAnalytics < Base
    OMNI_REPORTS_LAUNCH_FEATURE = 'omni_reports'.freeze

    def run_migration_for_omni_analytics
      @account_id.nil? ? run_migration_for_all_accounts : run_migration_for_single_account(@account_id)
    end

    def run_migration_for_single_account(account_id)
      Sharding.select_shard_of(account_id) do
        account = Account.find(account_id)
        account.make_current
        migration_process(account)
      end
    end

    def run_migration_for_all_accounts
      Sharding.run_on_all_shards do
        Account.active_accounts.find_in_batches(batch_size: 300) do |accounts|
          accounts.each do |account|
            account.make_current
            migration_process(account)
          end
        end
      end
    end

    def migration_process(account)
      if account.omni_bundle_account?
        account.launch(OMNI_REPORTS_LAUNCH_FEATURE)
        account.account_managers.first.make_current
        roles = account.roles
        roles.each do |role|
          next unless role.privilege?(:view_analytics)

          role.privileges = (role.privileges.to_i | (1 << PRIVILEGES[:view_omni_analytics])).to_s
          role.save!
        end
      end
    rescue StandardError => e
      account.rollback(OMNI_REPORTS_LAUNCH_FEATURE)
      Rails.logger.info "Account_id: #{account.id} \t error: #{e.inspect} \t backtrace: #{e.backtrace}"
    ensure
      Account.reset_current_account
    end
  end
end

# Migration::EnableOmniAnalytics.new(account_id: 1).run_migration_for_omni_analytics
