class Helpdesk::EmailHourlyUpdate < ActiveRecord::Base

  MAX_RUN_TIME = 30.minutes

  def lock_exclusively!
    now = self.class.db_time_now
    affected_rows = self.class.update_all(["locked_at = ?", now], ["id = ? and (locked_at is null or locked_at < ?)", id, (now - MAX_RUN_TIME.to_i)])
    if affected_rows == 1
      self.locked_at = now
      return true
    else
      return false
    end
  end

  def process_with_lock
    unless lock_exclusively!
      Rails.logger.warn "Failed to aquire exclusive lock for #{self.inspect}"
      return
    end
    ::Email::S3RetryWorker.perform_async({ :hourly_path => hourly_path })
  end
  
  def self.db_time_now
    (ActiveRecord::Base.default_timezone == :utc) ? Time.now.utc : Time.zone.now
  end

  def unlock
    self.locked_at = nil
    save!
  end

  def self.process_failed_emails
    max_processing_time = Helpdesk::EMAIL[:processing_timeout] * Helpdesk::EMAIL[:retry_count]
    hourly_paths = Helpdesk::EmailHourlyUpdate.where("created_at <  ?", db_time_now - max_processing_time ) 
    hourly_paths.each do |hp|
      Rails.logger.info "Retrying emails for the path #{hp.hourly_path}"
      hp.process_with_lock
    end
  end
 
end
