module TestFileMethods
  GLOBAL_TABLES = [
    'affiliate_discount_mappings',
    'affiliate_discounts',
    'shard_mappings',
    'domain_mappings',
    'google_domains',
    'subscription_affiliates',
    'subscription_announcements',
    'delayed_jobs',
    'features',
    'wf_filters',
    'global_blacklisted_ips',
    'accounts',
    'subscription_plans',
    'schema_migrations',
    'subscription_currencies',
    'itil_asset_plans',
    'subscription_payments',
    'mailbox_jobs',
    'service_api_keys',
    'pod_shard_conditions',
    'remote_integrations_mappings'
  ].freeze

  def set_autoincrement_ids
    shard_name = ActiveRecord::Base.current_shard_selection.shard.to_s
    if shard_name.include?('sandbox')
      auto_increment_id = AutoIncrementId[shard_name].to_i
      (ActiveRecord::Base.connection.tables - GLOBAL_TABLES).each do |table_name|
        puts "Altering auto increment id for #{table_name}"
        auto_increment_query = "ALTER TABLE #{table_name} AUTO_INCREMENT = #{auto_increment_id}"
        ActiveRecord::Base.connection.execute(auto_increment_query)
      end
    end
  end
end

include TestFileMethods
