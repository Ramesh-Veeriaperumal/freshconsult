module Redis::Keys::Semaphore
  SCHEDULER_SEMAPHORE = 'SCHEDULER_SEMAPHORE:%{account_id}:%{class_name}'.freeze
  FACEBOOK_SEMAPHORE = 'FACEBOOK_SEMAPHORE:%{account_id}:%{page_id}'.freeze
end
