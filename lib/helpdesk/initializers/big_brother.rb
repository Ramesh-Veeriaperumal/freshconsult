module BigBrother

  def record_stats
    if self.respond_to?(:account_id)
      log_activerecord
    end
  end

  def self.included(receiver)
    receiver.after_commit :record_stats , :on => :create
  end
  
  def logging_format
    log_file_format = "#{get_shard_name}.model.#{camel_to_table}.#{account_id}"
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

end

ActiveRecord::Base.send(:include,BigBrother)