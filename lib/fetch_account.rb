module FetchAccount

  protected
  
    def current_account(req = nil)
     @current_account ||= retrieve_current_account(req)
    end

    def retrieve_current_account(req)
      Sharding.select_shard_of(req) do
        @current_portal = Portal.fetch_by_url(req)
        return @current_portal.account if @current_portal
      
        account = Account.fetch_by_full_domain(req) || 
                  (Rails.env.development? ? Account.first : nil)
        (raise ActiveRecord::RecordNotFound and return) unless account
      
        @current_portal = account.main_portal_from_cache
        account 
      end
    end
end