module Mobile::MobileHelperMethods

  MOBILE_URL = "/mobile/"

  AVAILABLE_MOBILE_VIEWS = { :tickets => {:show => "#{MOBILE_URL}#tickets/show/{{params.id}}"} }
  
  def self.included(base)
    base.send :helper_method, :set_mobile, :mobile?
  end

  private

    def mobile?
      user_agent = request.env["HTTP_USER_AGENT"]
      Rails.logger.debug "user_agent #{user_agent}"
      @mobile_user_agent ||= (user_agent  && user_agent[/(Mobile\/.+Safari)|(Android)/])
    end

    def set_mobile
      if mobile?
        params[:format] = "mob"
      end
    end

    def require_user_login
     render :json=>{:status_code=>302, :Location=>login_url},:status => 302 unless current_user
    end

    def has_mobile_view?
      AVAILABLE_MOBILE_VIEWS.has_key?(controller_name.to_sym) ?
        AVAILABLE_MOBILE_VIEWS[controller_name.to_sym].has_key?(action_name.to_sym) : false 
    end

    def construct_url(url,params)
      Liquid::Template.parse(url).render("params" => params)
    end

    def get_mobile_url
      construct_url(AVAILABLE_MOBILE_VIEWS[controller_name.to_sym][action_name.to_sym],params)
    end

    def redirect_to_mobile_url
      if !current_user.nil? and mobile? and !"mob".eql?(params[:format]) and has_mobile_view?
         redirect_to get_mobile_url
      end
    end
end
