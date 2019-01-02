module Redis::Semaphore
  def get_semaphore(key)
    $semaphore.perform_redis_op('get', key)
  end

  def set_semaphore(key, value = 1)
    $semaphore.perform_redis_op('set', key, value)
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
end
