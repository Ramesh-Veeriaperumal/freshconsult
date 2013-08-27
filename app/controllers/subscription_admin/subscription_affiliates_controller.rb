class SubscriptionAdmin::SubscriptionAffiliatesController < ApplicationController
  
  include ModelControllerMethods
  include AdminControllerMethods
  
  before_filter :set_selected_tab  
  before_filter :load_discounts, :only => [ :new, :edit ]

  def add_subscription
    @subscription_affiliate = SubscriptionAffiliate.find(params[:id])
    
    if request.post? and !params[:domain].blank?
      account = Account.find_by_full_domain(params[:domain])
      if account and attach_affiliate(account)
        flash[:notice] = 'Subscription added to affiliate.'
      else
        flash[:error] = 'There is no account with the specified domain.'
      end

      render :action => 'show'
    end
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
        Billing::Subscription.new.add_discount(account, discount.code)
      end
    end
end