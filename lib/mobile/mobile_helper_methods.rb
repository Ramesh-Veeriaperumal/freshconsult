module Mobile::MobileHelperMethods

  MOBILE_URL = "/mobile/"
  
  def self.included(base)
    base.send :helper_method, :set_mobile, :mobile?
  end

  private

    def mobile?
      mobile_user_agent?
    end

    def mobile_user_agent?
      user_agent = request.env["HTTP_USER_AGENT"]
      Rails.logger.debug "user_agent #{user_agent}"
      @mobile_user_agent ||= (user_agent  && user_agent[/(Mobile\/.+Safari)|(Android)/])
    end

    def set_mobile
      if mobile_user_agent?
        params[:format] = "mob"
      end
    end

    def require_user_login
     render :json=>{:status_code=>302, :Location=>login_url},:status => 302 unless current_user
    end

    def mobile_ticket_url(id)
      "#{MOBILE_URL}#tickets/show/#{id}"
    end 
end
