module SubscriptionSystem

  # Set up some stuff for ApplicationController
  def self.included(base)
    #base.send :before_filter, :login_required
    base.send :before_filter, :set_affiliate_cookie
    #:admin?
    base.send :helper_method, :current_account, :admin_subdomain?, :feature?,
        :allowed_in_portal?, :current_portal, :main_portal?
  end

  def requires_forums_feature
    return if feature?(:forums)
    error_view = current_account.subscription.forum_available_plan? ? "forums_disabled" : "non_covered_feature"
    render is_native_mobile? ? { :json => { :requires_feature => false } } : { :template => "/errors/#{error_view}.html", :locals => {:feature => :forums} }
  end
  
  def requires_feature(f)
	return if feature?(f)
	render is_native_mobile? ? { :json => { :requires_feature => false } } : requires_feature_template(f)
  end
  
  def check_portal_scope(f)
    require_user unless allowed_in_portal?(f)
  end

  def requires_bitmap_feature(feature)
    render requires_feature_template(feature) unless current_account.has_feature?(feature)
  end
  
  protected
  
    def current_account
      @current_account ||= retrieve_current_account
    end
    
    def current_portal
      current_account
      @current_portal
    end
    
    def main_portal?
      current_portal.main_portal
    end
    
    # def admin?
    #   logged_in? && current_user.admin?
    #end
    
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

  private
    def retrieve_current_account
      @current_portal = Portal.fetch_by_url request_host 
      @current_portal.make_current if @current_portal
      return @current_portal.account if @current_portal
      
      account = Account.fetch_by_full_domain(request_host) || 
                  (Rails.env.development? ? Account.first : nil)
      (raise ActiveRecord::RecordNotFound and return) unless account
      
      @current_portal = account.main_portal_from_cache
      @current_portal.make_current if @current_portal
      (raise ActiveRecord::RecordNotFound and return) unless @current_portal
      account
    end

    def requires_feature_template(feature)
      { 
        template: "/errors/non_covered_feature.html", 
        locals: { 
          feature: feature 
        } 
      }
    end
end
