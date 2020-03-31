module Account::SidekiqControl::RouteDrop
  extend self
  # To add worker of an account to blackhole  ie to skip it totally account.blackhole_add_workers(['Namespace::Hardworker'])
  #
  # To add worker of all the accounts to blackhole account.blackhole_add_workers(['Namespace::Hardworker'], 'all')
  def blackhole_add_workers(worker_name = [], account_id = Account.current.id)
    worker_hash = {}
    redis_pool do |redis|
      worker_name.each do |worker|
        worker_hash[account_worker_key(account_id, worker)] = 'drop'
      end
      redis.mapped_mset(worker_hash)
    end
    Rails.logger.warn "account : #{account_id}, #{worker_name} added to blackhole workers"
  end

  def blackhole_remove_workers(worker_name = [], account_id = Account.current.id)
    redis_pool do |redis|
      worker_name.each do |worker|
        redis.del(account_worker_key(account_id, worker))
        Rails.logger.info "account : #{account_id}, #{worker_name} removed from blackhole workers"
      end
    end
  end

  def blackhole_worker?(worker_name, account_id = Account.current.id)
    redis_pool do |redis|
      redis.get(account_worker_key(account_id, worker_name)) == 'drop'
    end
  end

  # To reroute a worker of an account to another queue do this account.route_add_workers(default, ['Namespace::Hardworker'])
  #
  # To reroute a all workers to another queue do this  account.route_add_workers(default, ['Namespace::Hardworker'], 'all')
  def route_add_workers(queue, worker_name = [], account_id = Account.current.id)
    worker_hash = {}
    redis_pool do |redis|
      worker_name.each do |worker|
        worker_hash[account_worker_key(account_id, worker)] = "#{queue}_queue"
      end
      redis.mapped_mset(worker_hash)
    end
    Rails.logger.info "account : #{account_id}, #{worker_hash.inspect} rerouted to #{queue}"
  end

  def route_remove_workers(worker_name = [], account_id = Account.current.id)
    redis_pool do |redis|
      worker_name.each do |worker|
        redis.del(account_worker_key(account_id, worker))
        Rails.logger.info "account : #{account_id}, #{worker_name} removed from rerouted queue"
      end
    end
  end

  def route_worker?(worker_name, queue)
    redis_pool do |redis|
      redis.get(account_worker_key(Account.current.id, worker_name)) == "#{queue}_queue"
    end
  end

  def account_worker_key(account_id, worker_name)
    format(BG_ACCOUNT_WORKER, account_id: account_id, worker: worker_name)
  end

  def account_reroute_or_all(account_id, worker_name)
    redis_pool do |redis|
      redis.mget(account_worker_key(account_id, worker_name), account_worker_key('all', worker_name))
    end
  end

  def via_redis_pool_exist?(worker_name)
    redis_pool do |redis|
      redis.exists(Account::SidekiqControl::Config::route_config_key(worker_name))
    end
  end

  private

    def redis_pool(&block)
      Sidekiq.redis(&block)
    end
end
