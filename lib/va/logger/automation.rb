class Va::Logger::Automation

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
      log_text = content.split('\n').map{ |c| "#{context_txt} #{c.inspect}" }.join('\n')
      logger.debug log_text
    rescue => e
      Rails.logger.debug "Error in writing to automation.log #{content.inspect}"
      Rails.logger.debug e.inspect
      NewRelic::Agent.notice_error(e, { :custom_params => { :description => "Error in writing to automation.log, #{e.message}" }})
    end

    def standard_content
      automation_log_vars = Thread.current[:automation_log_vars]
      content = "#{Thread.current[:message_uuid].try(:join, ' ')} A=#{automation_log_vars[:account_id]}::T=#{automation_log_vars[:ticket_id]}::U=#{automation_log_vars[:user_id]}"
      content << "::R=#{automation_log_vars[:rule_id]}" if automation_log_vars[:rule_id]
      content << "::#{Time.now.utc}"
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

    def unset_thread_variables
      Thread.current[:automation_log_vars]  = nil
    end
  end
end
