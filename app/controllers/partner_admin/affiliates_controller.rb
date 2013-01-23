class PartnerAdmin::AffiliatesController < ApplicationController

	prepend_before_filter :check_admin_subdomain
  skip_before_filter :check_privilege
  skip_before_filter :set_time_zone
  skip_before_filter :set_locale
  skip_before_filter :check_account_state
  skip_before_filter :ensure_proper_protocol
  skip_before_filter :check_day_pass_usage
  skip_before_filter :redirect_to_mobile_url
  before_filter :ensure_right_parameters, :only => [:add_affiliate_transaction]
  before_filter :fetch_account, :only => [:add_affiliate_transaction]
  before_filter :ensure_right_affiliate, :only => [:add_affiliate_transaction]


  def add_affiliate_transaction
  	unless params[:amount].to_f > 0
  	 SubscriptionAffiliate.add_affiliate(@account,params[:userID])
  	end
  	respond_to do |format|
    	format.xml  { head 200 }
	end
  end

  protected

    def ensure_right_parameters
     if ((!request.ssl?) or
      (!request.post?) or 
      (params[:tracking].blank?) or 
      (params[:userID].blank?) or 
      (params[:commission].blank?) or
      (params[:transID].blank?) or
      (params[:amount].blank?))
      return render :xml => ArgumentError, :status => 500
 	 end
    end

  def ensure_right_affiliate
   unless SubscriptionAffiliate.check_affiliate_in_metrics?(@account,params[:userID])   
    return render :xml => ActiveRecord::RecordNotFound, :status => 404 
   end
  end
  
  def fetch_account
    @account = Account.find_by_full_domain(params[:tracking])	
    return render :xml => ActiveRecord::RecordNotFound, :status => 404 unless @account
  end

  def check_admin_subdomain
    raise ActionController::RoutingError, "Not Found" unless partner_subdomain?
  end
    
  def partner_subdomain?
    request.subdomains.first == AppConfig['partner_subdomain']
  end
  
end