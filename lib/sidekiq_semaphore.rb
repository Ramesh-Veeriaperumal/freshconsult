module SidekiqSemaphore
  include Redis::Keys::Semaphore
  include Redis::Semaphore
  SEMAPHORE_EXPIRY = 10.minutes

  def semaphore(key)
    if semaphore_exists?(key)
      executing_from = get_semaphore(key)
      Rails.logger.info "Already running Sidekiq Worker :: #{self.class.name} :: for #{key} :: from #{executing_from}"
      return
    end
    begin
      set_semaphore_with_expiry(key, Time.now.utc.to_s, ex: SEMAPHORE_EXPIRY)
      Rails.logger.info "Sidekiq Worker :: #{self.class.name} :: for #{key} :: Starting at #{Time.now.utc}"
      yield
    ensure
      del_semaphore(key)
      Rails.logger.info "Sidekiq Worker :: #{self.class.name} :: for #{key} :: done at #{Time.now.utc}"
    end
  end
end