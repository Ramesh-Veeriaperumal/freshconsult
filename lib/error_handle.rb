module ErrorHandle
  
  def sandbox(return_value = nil)
      begin
        return_value = yield
      rescue Errno::ECONNRESET => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Timeout::Error => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue EOFError => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Errno::ETIMEDOUT => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Errno::ECONNREFUSED => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Errno::EAFNOSUPPORT => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue OpenSSL::SSL::SSLError => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue SystemStackError => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue 
        RAILS_DEFAULT_LOGGER.debug "Something wrong happened!"
      end
      
      return return_value
      
    end

end