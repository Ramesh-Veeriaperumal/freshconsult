module FetchAccount

  protected
  
    def current_account(req = nil)
      return Account.first if Rails.env.development?
      Sharding.selec_shard_of(req) do
        @current_portal = Portal.fetch_by_url(req)
        return @current_portal.account if @current_portal
      
        account = Account.fetch_by_full_domain(req) || 
                  (Rails.env.development? ? Account.first : nil)
        (raise ActiveRecord::RecordNotFound and return) unless account
      
        @current_portal = account.main_portal_from_cache
        return account 
      end
    end
end