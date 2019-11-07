module Redis::Semaphore
  def get_semaphore(key)
    $semaphore.perform_redis_op('get', key)
  end

  def set_semaphore(key, value = 1, expiry = nil)
    expiry ? $semaphore.perform_redis_op('setex', key, expiry, value) : $semaphore.perform_redis_op('set', key, value)
  end

  def set_semaphore_with_expiry(key, value, options)
    newrelic_begin_rescue { $semaphore.perform_redis_op('set', key, value, options) }
  end

  def semaphore_exists?(key)
    $semaphore.perform_redis_op('exists', key)
  end

  def del_semaphore(*key)
    $semaphore.perform_redis_op('del', *key)
  end

  def multi_semaphore
    $semaphore.perform_redis_op('multi')
  end

  def exec_semaphore
    $semaphore.perform_redis_op('exec')
  end

  def lock_and_run(key, expiry = nil)
    return if semaphore_exists?(key)

    set_semaphore(key, 1, expiry)
    yield
  ensure
    del_semaphore(key)
  end
end
