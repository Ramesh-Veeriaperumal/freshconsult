module Mobile::MobileHelperMethods
  def self.included(base)
    base.send :helper_method, :set_mobile
  end

  private

     def mobile_user_agent?
      user_agent = request.env["HTTP_USER_AGENT"]
      @mobile_user_agent ||= (user_agent  && user_agent[/(Mobile\/.+Safari)/] )
    end

    def set_mobile
      if mobile_user_agent?
        params[:format] = :mob
      end
    end
end
