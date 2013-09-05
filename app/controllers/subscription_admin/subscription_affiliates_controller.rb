class SubscriptionAdmin::SubscriptionAffiliatesController < ApplicationController
  
  include ModelControllerMethods
  include AdminControllerMethods
  
  before_filter :set_selected_tab  
  before_filter :load_discounts, :only => [ :new, :create, :edit, :update ]
  
  skip_filter :run_on_slave, :only => [ :create, :update, :add_subscription ]


  def add_subscription
    @subscription_affiliate = SubscriptionAffiliate.find(params[:id])
    
    if request.post? and !params[:domain].blank?
      account = Account.find_by_full_domain(params[:domain])
      if account and attach_affiliate(account)
        flash[:notice] = 'Subscription added to affiliate.'
      else
        flash[:error] = 'There is no account with the specified domain.'
      end
    end

    render :action => 'show'
  end

  protected
    def set_selected_tab
       @selected_tab = :affiliates
    end
    
    def load_discounts
      @free_agent_coupons = AffiliateDiscount.free_agent_coupons
      @percentage_coupons = AffiliateDiscount.percentage_coupons
    end

    def attach_affiliate(account)
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