module BigBrother

  def record_stats
    if self.respond_to?(:account_id)
      log_activerecord
    end
    track_models if TRACKED_MODELS.include?(self.class.to_s)
  end

  def self.included(receiver)
    receiver.after_commit :record_stats , :on => :create
  end
  
  def logging_format
    log_file_format = "shard_name=#{get_shard_name}, model_name=#{camel_to_table}, account_id=#{account_id}"
  end

  def get_shard_name
    ActiveRecord::Base.current_shard_selection.shard
  end

  def camel_to_table
    self.class.to_s.gsub("::","").tableize
  end

  def log_activerecord
    init_logger
    @@big_brother_logger.info logging_format
  end

  def init_logger
    @@big_brother_logger ||= CustomLogger.new("#{Rails.root}/log/big_brother.log")
  end

  def track_models
    statsd_increment(get_shard_name,"#{camel_to_table}_creation_counter")
    statsd_increment(get_shard_name,"#{TRACKED_TICKET_SOURCE[self.source]}_ticket_creation_counter") if  self.class.to_s == "Helpdesk::Ticket" && TRACKED_TICKET_SOURCE.has_key?(self.source)
  end

end

ActiveRecord::Base.send(:include,BigBrother)