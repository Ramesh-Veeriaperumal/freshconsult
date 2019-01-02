module SchedulerSemaphoreMethods
  include Redis::Keys::Semaphore
  include Redis::Semaphore

  def set_scheduler_semaphore(account_id, class_name)
    key = semaphore_key(account_id, class_name)
    set_semaphore(key)
  end

  def get_scheduler_semaphore(account_id, class_name)
    key = semaphore_key(account_id, class_name)
    get_semaphore(key)
  end

  def del_scheduler_semaphore(account_id, class_name)
    key = semaphore_key(account_id, class_name)
    del_semaphore(key)
  end

  def scheduler_semaphore_exists?(account_id, class_name)
    key = semaphore_key(account_id, class_name)
    semaphore_exists?(key)
  end

  private

    def semaphore_key(account_id, class_name)
      format(SCHEDULER_SEMAPHORE, account_id: account_id, class_name: class_name)
    end
end
