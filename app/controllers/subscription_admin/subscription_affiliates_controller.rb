class SubscriptionAdmin::SubscriptionAffiliatesController < ApplicationController
  
  include ModelControllerMethods
  include AdminControllerMethods
  
  before_filter :set_selected_tab  
  before_filter :load_discounts, :only => [ :new, :create, :edit, :update ]
  
  skip_filter :run_on_slave, :only => [ :create, :update, :add_subscription ]

  RESELLER_TOKEN = "FDRES"
  AFFILIATE = "Share A Sale"

  def add_subscription
    @subscription_affiliate = SubscriptionAffiliate.find(params[:id])
    
    if request.post? and !params[:domain].blank?
      domain = DomainMapping.find_by_domain(params[:domain])
     
      if domain and attach_affiliate(domain)
        flash[:notice] = 'Subscription added to affiliate.'
      else
        flash[:error] = 'There is no account with the specified domain.'
      end
    end

    render :action => 'show'
  end

  def index
    @resellers = SubscriptionAffiliate.all.select{ |affiliate| affiliate.token.include?(RESELLER_TOKEN) }
    @shareasale_affiliates = SubscriptionAffiliate.all.select{ |affiliate| affiliate.name.eql?(AFFILIATE) }
    @others = SubscriptionAffiliate.all - @resellers - @shareasale_affiliates
  end

  protected
    def set_selected_tab
       @selected_tab = :affiliates
    end

    def check_admin_user_privilege
      if !(current_user and  current_user.has_role?(:affiliates))
        flash[:notice] = "You dont have access to view this page"
        redirect_to(admin_subscription_login_path)
      end
    end 
    
    def load_discounts
      @free_agent_coupons = AffiliateDiscount.free_agent_coupons
      @percentage_coupons = AffiliateDiscount.percentage_coupons
    end

    def attach_affiliate(domain)
      account_id = domain.account_id
      Sharding.select_shard_of(account_id) do
         account = Account.find(account_id)
        SubscriptionAffiliate.add_affiliate(account, @subscription_affiliate.token)
          @subscription_affiliate.discounts.each do |discount|
          begin
            Billing::Subscription.new.add_discount(account, discount.code)
          rescue
            flash[:error] = 'There was an error applying discounts in ChargeBee.'          
          end
        end
      end
    end
end