class PartnerAdmin::AffiliatesController < ApplicationController

	prepend_before_filter :check_admin_subdomain
    skip_before_filter :set_time_zone
    skip_before_filter :set_locale
    skip_before_filter :check_account_state
    skip_before_filter :ensure_proper_protocol
    skip_before_filter :check_day_pass_usage
 
  before_filter :login_affiliate_auth, :only => [:add_affiliate_transaction]
  before_filter :ensure_right_parameters, :only => [:add_affiliate_transaction]

  def add_affiliate_transaction
  	unless params[:amount].to_f > 0
  	 account = fetch_account
  	  return render :xml => ActiveRecord::RecordNotFound, :status => 404 unless account
  	  SubscriptionAffiliate.add_affiliate(account,params[:userID])
  	end
  	respond_to do |format|
    	format.xml  { head 200 }
	end
  end

  protected

    def ensure_right_parameters
     if ((!request.post?) or 
      (params[:tracking].blank?) or 
      (params[:userID].blank?) or 
      (params[:commission].blank?) or
      (params[:transID].blank?) or
      (params[:amount].blank?))
      return render :xml => ArgumentError, :status => 500
 	 end
    end

    
    def login_affiliate_auth
       authenticate_or_request_with_http_basic do |username, password|
         username == 'freshdesk' && fetch_hash_key(password) == '04070c1b999b313d837ca1a64867a3bd'
       end
     end

     def fetch_hash_key(password)
      Digest::MD5.hexdigest(Helpdesk::SHARED_SECRET + password)
    end
    
    #This may change to full domain
    def fetch_account
     	Account.find_by_id(params[:tracking])	
    end

     def check_admin_subdomain
      raise ActionController::RoutingError, "Not Found" unless partner_subdomain?
    end
    def partner_subdomain?
      request.subdomains.first == AppConfig['partner_subdomain']
    end
  
end