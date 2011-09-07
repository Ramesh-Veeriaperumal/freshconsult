class SubscriptionAdmin::SubscriptionsController < ApplicationController
  include ModelControllerMethods
  include AdminControllerMethods
  
  def index
    @stats = SubscriptionPayment.stats if params[:page].blank?
    @subscriptions = search(params[:search])
    @subscriptions = @subscriptions.paginate( :page => params[:page], :per_page => 30)
  end
  
  def extend_trial
    @subscription = Subscription.find(params[:id])
    if request.post? and !params[:trial_days].blank?
      @subscription.update_attributes(:next_renewal_at => @subscription.next_renewal_at.advance(:days => params[:trial_days].to_i))
    end
    render :action => 'show'
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
  
   def search(search)
    if search
      Subscription.find(:all,:include => :account,
                   :joins => "INNER JOIN accounts on accounts.id = subscriptions.account_id ",
                   :conditions => ['full_domain LIKE ?', "%#{search}%"]) 
    else
      Subscription.find(:all,:include => :account, :order => 'created_at desc')
    end
  end
    
    def redirect_url
      action_name == 'destroy' ? { :action => 'index'} : [:admin, @subscription]
    end
  
end
