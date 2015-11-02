module AgentLoggerHelper

  def self.included(receiver)
    receiver.after_save :agent_login
    receiver.before_destroy :agent_logout
  end

  def agent_login
    log_agent_info(@record)
  end

  def agent_logout
    log_agent_info(@record,destroy = true)
  end

  def log_agent_info(current_user, destroy = false)
    if current_user && current_user.agent?
      if controller.cookies["fd"].blank?
        controller.cookies["fd"] = SecureRandom.uuid
      end
      action_type = destroy ? "destroy" : "create" 
      Rails.logger.debug "::Agent Account Sharing::: #{Time.now.to_formatted_s}, account_id=#{current_user.account_id}, user_id=#{current_user.id}, user_agent=#{controller.request.env['HTTP_USER_AGENT']}, ip=#{controller.request.remote_ip}, device_id=#{controller.cookies['fd']}, action=#{action_type}"
    end
  rescue Exception => e
    NewRelic::Agent.notice_error(e)
  end

end 


