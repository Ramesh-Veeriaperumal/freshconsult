module FetchAccount

	protected
  
    def current_account(req = nil)
      @current_account ||= retrieve_current_account(req)
    end

  private
    def retrieve_current_account(req)
    	@current_portal = Portal.fetch_by_url(req || request.host)
      return @current_portal.account if @current_portal
      
      account = Account.fetch_by_full_domain(req || request.host) || 
                  (Rails.env.development? ? Account.first : nil)
      (raise ActiveRecord::RecordNotFound and return) unless account
      
      @current_portal = account.main_portal_from_cache
      account
    end

end