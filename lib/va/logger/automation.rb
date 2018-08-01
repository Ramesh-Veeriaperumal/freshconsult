class Va::Logger::Automation

  EXECUTION_COMPLETED = 'EXECUTION COMPLETED'

  class << self
    def log_path
      "#{Rails.root}/log/automation.log"
    end

    def logger
      @@automation_logger ||= Logger.new(log_path)
    end

    def log content
      return if Thread.current[:automation_log_vars].blank?
      context_txt = standard_content
      log_text_array = content.split('\n').map{ |c| "#{context_txt}, content=#{c}" }
      log_text_array.each {|log_text| logger.debug log_text}
    rescue => e
      Rails.logger.debug "Error in writing to automation.log #{content.inspect}"
      Rails.logger.debug e.inspect
      NewRelic::Agent.notice_error(e, { :custom_params => { :description => "Error in writing to automation.log, #{e.message}" }})
    end

    def standard_content
      automation_log_vars = Thread.current[:automation_log_vars]
      content = "#{Time.now.utc.strftime '%Y-%m-%d %H:%M:%S'} uuid=#{Thread.current[:message_uuid].try(:join, ' ')}, A=#{automation_log_vars[:account_id]}, T=#{automation_log_vars[:ticket_id]}, U=#{automation_log_vars[:user_id]}, R=#{automation_log_vars[:rule_id]}"
      content << ", time=#{automation_log_vars[:time]}" if automation_log_vars[:time]
      content << ", type=#{automation_log_vars[:rule_type]}" if automation_log_vars[:rule_type]
      content << ", start_time=#{automation_log_vars[:start_time]}" if automation_log_vars[:start_time]
      content << ", end_time=#{automation_log_vars[:end_time]}" if automation_log_vars[:end_time]
      content << ", executed=#{automation_log_vars[:executed]}" if automation_log_vars[:executed]
      content
    end

    def set_thread_variables(account_id, ticket_id=nil, user_id=nil, rule_id=nil)
      thread_hash = {}
      thread_hash[:account_id] = account_id if account_id
      thread_hash[:ticket_id] = ticket_id if ticket_id
      thread_hash[:user_id] = user_id if user_id
      thread_hash[:rule_id] = rule_id if rule_id
      Thread.current[:automation_log_vars] = thread_hash if thread_hash.present?
    end

    def set_rule_id rule_id
      Thread.current[:automation_log_vars][:rule_id] = rule_id if rule_id && Thread.current[:automation_log_vars].present?
    end

    def unset_rule_id
      Thread.current[:automation_log_vars][:rule_id] = nil
    end

    def log_execution_and_time(time, executed, rule_type=nil, start_time=nil, end_time=nil)
      return if Thread.current[:automation_log_vars].blank?
      Thread.current[:automation_log_vars][:time] = time.round(5) if time
      Thread.current[:automation_log_vars][:executed] = executed if executed
      Thread.current[:automation_log_vars][:rule_type] = rule_type if rule_type
      Thread.current[:automation_log_vars][:start_time] = Time.at(start_time).utc if start_time
      Thread.current[:automation_log_vars][:end_time] = Time.at(end_time).utc if end_time
      log EXECUTION_COMPLETED
      unset_execution_and_time
    end

    def log_error error, exception, args=nil
      log "error_message=#{error}, info=#{args.inspect}, exception=#{exception.try(:message)}, backtrace=#{exception.try(:backtrace)}"
    end

    def unset_execution_and_time
      Thread.current[:automation_log_vars][:time] = nil
      Thread.current[:automation_log_vars][:executed] = nil
      Thread.current[:automation_log_vars][:rule_type] = nil
      Thread.current[:automation_log_vars][:start_time] = nil
      Thread.current[:automation_log_vars][:end_time] = nil
    end

    def unset_thread_variables
      Thread.current[:automation_log_vars]  = nil
    end
  end
end
