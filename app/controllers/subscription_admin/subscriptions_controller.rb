class SubscriptionAdmin::SubscriptionsController < ApplicationController
  include ModelControllerMethods
  include AdminControllerMethods
  
  def index
    @stats = SubscriptionPayment.stats if params[:page].blank?
    @subscriptions = Subscription.paginate(:include => :account, :page => params[:page], :per_page => 30, :order => 'accounts.created_at desc')
  end
  
  def charge
    if request.post? && !params[:amount].blank?
      load_object
      if @subscription.misc_charge(params[:amount])
        flash[:notice] = 'The card has been charged.'
        redirect_to :action => "show"
      else
        render :action => 'show'
      end
    end
  end
  
  def customers
    @subscriptions = Subscription.paginate(:include => :account, :page => params[:page], :per_page => 30, :order => 'accounts.created_at desc',
                                           :conditions => ['card_number is not null and state = ? ','active'] )
  end
  
  protected
    
    def redirect_url
      action_name == 'destroy' ? { :action => 'index'} : [:admin, @subscription]
    end
  
end
