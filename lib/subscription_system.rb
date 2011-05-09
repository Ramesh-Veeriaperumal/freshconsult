module SubscriptionSystem

  # Set up some stuff for ApplicationController
  def self.included(base)
    #base.send :before_filter, :login_required
    base.send :before_filter, :set_affiliate_cookie
    base.send :helper_method, :current_account, :admin?, :admin_subdomain?, :feature?, :allowed_in_portal?
    base.send :filter_parameter_logging, :password, :creditcard
  end
  
  def requires_feature(f)
    render("/errors/non_covered_feature") unless feature?(f)
  end
  
  def check_portal_scope(f)
    require_user unless allowed_in_portal?(f)
  end
  
  protected
  
    def current_account
      @current_account ||= Account.find(:first, :conditions => ["full_domain = ? or helpdesk_url = ?", request.host, request.host]) || 
                                   (Rails.env.development? ? Account.first : nil)
      (render("/errors/invalid_domain") and raise ActiveRecord::RecordNotFound) unless @current_account
      @current_account
    end
    
    def admin?
      logged_in? && current_user.admin?
    end
    
    def admin_subdomain?
      request.subdomains.first == AppConfig['admin_subdomain']
    end
    
    def feature?(f)
      current_account.features? f
    end
    
    def allowed_in_portal?(f)
      (logged_in? || feature?(f))
    end

    def set_affiliate_cookie
      if !params[:ref].blank? && affiliate = SubscriptionAffiliate.find_by_token(params[:ref])
        cookies[:affiliate] = { :value => params[:ref], :expires => 1.month.from_now }
      end
    end

end