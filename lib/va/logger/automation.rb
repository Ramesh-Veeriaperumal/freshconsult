class Va::Logger::Automation

  EXECUTION_COMPLETED = 'EXECUTION COMPLETED'

  class << self

    def log(content, append_default_content = false)
      return if Thread.current[:automation_log_vars].blank?
      context_txt = log_content(append_default_content)
      Rails.logger.info("#{context_txt}#{content}")
    end

    def log_content(append_default_content, content = '')
      automation_log_vars = Thread.current[:automation_log_vars]
      content = "A=#{automation_log_vars[:account_id]} T=#{automation_log_vars[:ticket_id]} " if append_default_content
      content += "U=#{automation_log_vars[:user_id]} " if automation_log_vars[:user_id] && append_default_content
      content += "R=#{automation_log_vars[:rule_id]} " if automation_log_vars[:rule_id]
      content += "time=#{automation_log_vars[:time]} " if automation_log_vars[:time]
      content += "type=#{automation_log_vars[:rule_type]} " if automation_log_vars[:rule_type]
      content += "start_time=#{automation_log_vars[:start_time]} " if automation_log_vars[:start_time]
      content += "end_time=#{automation_log_vars[:end_time]} " if automation_log_vars[:end_time]
      content += "executed=#{automation_log_vars[:executed]} " if automation_log_vars[:executed]
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
      log(EXECUTION_COMPLETED, true)
      unset_execution_and_time
    end

    def log_error error, exception, args=nil
      log("error_message=#{error}, info=#{args.inspect}, exception=#{exception.try(:message)}, backtrace=#{exception.try(:backtrace)}", true)
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
