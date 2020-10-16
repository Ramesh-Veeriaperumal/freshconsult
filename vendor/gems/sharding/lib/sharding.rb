require 'models/shard_mapping'
require 'models/domain_mapping'
require 'exceptions/domain_not_ready'
require 'exceptions/shard_not_found'
require 'models/pod_shard_condition'
require 'exceptions/account_blocked'
class Sharding
  
 class << self
  def select_shard_of(shard_key, &block)
    shard = is_numeric?(shard_key) ? ShardMapping.lookup_with_account_id(shard_key) : ShardMapping.lookup_with_domain(shard_key)
    check_shard_status(shard)
    shard_name = shard.shard_name 
    ActiveRecord::Base.on_shard(shard_name.to_sym,&block)
  end

  def admin_select_shard_of(shard_key, &block)
    shard = is_numeric?(shard_key) ? ShardMapping.lookup_with_account_id(shard_key) : ShardMapping.lookup_with_domain(shard_key)
    raise ActiveRecord::RecordNotFound  if shard.nil?
    shard_name = shard.shard_name 
    ActiveRecord::Base.on_shard(shard_name.to_sym,&block)
  end

  def run_on_slave(&block)
    # TODO Remove the thread variable usage after fixing switch to replica
    Thread.current[:replica] = true
    ActiveRecord::Base.on_slave(&block)
  ensure
    Thread.current[:replica] = nil
  end

  def run_on_master(&block)
    on_replica = Thread.current[:replica]
    Thread.current[:replica] = false
    ActiveRecord::Base.on_master(&block)
  ensure
    Thread.current[:replica] = on_replica
  end

  def select_latest_shard(&block)
    ActiveRecord::Base.on_shard(ShardMapping.latest_shard,&block)
  end

  def run_on_shard(shard_name,&block)
    ActiveRecord::Base.on_shard(shard_name.to_sym,&block)
  end

  def all_shards
    ActiveRecord::Base.shard_names
  end

  def run_on_all_shards(&block)
    results = ActiveRecord::Base.on_all_shards(&block)
    results.flatten
  end

  def run_on_all_slaves(&block)
    results = run_on_all_shards { run_on_slave(&block)}
  end

  def execute_on_all_shards(&block)
    ActiveRecord::Base.on_all_shards(&block)
  end

  private

  def check_shard_status(shard)
    raise ShardNotFound  if shard.nil?
    raise AccountBlocked if shard.blocked?
    raise DomainNotReady  unless shard.ok?
  end

  def is_numeric?(str) #Need to move to shard
    true if Float(str) rescue false
  end

 end

end
