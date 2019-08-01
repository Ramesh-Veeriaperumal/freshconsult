module Account::SidekiqControl::RouteDrop

  def blackhole_add_workers(worker_name = [])
    worker_name.each do |worker|
      set_others_redis_key(account_worker_key(Account.current.id, worker), 'drop')
      Rails.logger.warn "account : #{Account.current.id}, #{worker_name} added to blackhole workers"
    end
  end

  def blackhole_remove_workers(worker_name = [])
    worker_name.each do |worker|
      remove_others_redis_key(account_worker_key(Account.current.id, worker))
      Rails.logger.info "account : #{Account.current.id}, #{worker_name} removed from blackhole workers"
    end
  end

  def blackhole_worker?(worker_name)
    get_others_redis_key(account_worker_key(Account.current.id, worker_name)) == 'drop'
  end

  def route_add_workers(queue, worker_name = [])
    worker_name.each do |worker|
      set_others_redis_key(account_worker_key(Account.current.id, worker), "#{queue}_queue")
      Rails.logger.info "account : #{Account.current.id}, #{worker_name} rerouted to #{queue}_queue"
    end
  end

  def route_remove_workers(worker_name = [])
    worker_name.each do |worker|
      remove_others_redis_key(account_worker_key(Account.current.id, worker))
      Rails.logger.info "account : #{Account.current.id}, #{worker_name} removed from rerouted queue"
    end
  end

  def route_worker?(worker_name, queue)
    get_others_redis_key(account_worker_key(Account.current.id, worker_name)) == "#{queue}_queue"
  end

  def account_worker_key(account_id, worker_name)
    format(BG_ACCOUNT_WORKER, account_id: account_id, worker: worker_name)
  end
end
