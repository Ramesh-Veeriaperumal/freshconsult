module MetaDataCheck::MetaDataCheckMethods

  def self.accounts_data
    inconsistent_accounts = []
    redis_key = Redis::RedisKeys::META_DATA_TIMESTAMP
    $redis_others.perform_redis_op("set",redis_key, Time.now.utc - 24.hours) if !($redis_others.perform_redis_op("exists",redis_key))
    Sharding.run_on_all_slaves do
      Account.where(["accounts.updated_at > ? ",$redis_others.perform_redis_op("get",redis_key)]).find_in_batches(:batch_size => 100) do |account_info|
        account_info.each do |account|
          shard_record = ShardMapping.find(account.id) 
          request_parameters = {new_domain: account.full_domain,target_method: "check_domain_availability"}
          response = Fdadmin::APICalls.connect_main_pod(request_parameters)
          if !response["account_id"] || check_route53(account) || check_sendgrid(account)
            inconsistent_accounts << {:account_id => account["id"],:domain => account["full_domain"],:shard => shard_record.shard_name,:pod => shard_record.pod_info}
          end
        end
      end
    end
    $redis_others.perform_redis_op("set",redis_key,Time.now.utc)
    FreshopsMailer.inconsistent_accounts_summary(inconsistent_accounts) if inconsistent_accounts.length >= 1
  end

  def self.check_route53(account)
    begin
      response = $route_53.list_resource_record_sets(hosted_zone_id: PodDnsUpdate::DNS_CONFIG['hosted_zone'], start_record_name: account['full_domain'], start_record_type: 'CNAME', max_items: 1)
      (response.resource_record_sets && response.resource_record_sets.first[:name] == account['full_domain']+".") ? nil : account
    rescue Exception => e
      return account
    end
  end

  def self.check_sendgrid(account)
    return account if !SendgridDomainUpdates.new().sendgrid_domain_exists?(account['full_domain'])
  end

end