class SubscriptionAdmin::SubscriptionsController < ApplicationController
  
  DUMMY_ACCOUNTS = 2
  DUMMY_MONEY = 137.0
  DUMMY_AGENTS = 5
   
   
  
  include ModelControllerMethods
  include AdminControllerMethods
  
  def index
    @stats = SubscriptionPayment.stats if params[:page].blank?
    @customer_count = Subscription.customer_count - DUMMY_ACCOUNTS
    @monthly_revenue = Subscription.monthly_revenue - DUMMY_MONEY
    @cmrr = @monthly_revenue/@customer_count
    @customer_agent_count = Subscription.customers_agent_count - DUMMY_AGENTS
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
  
  def deleted_customers
    @deleted_customers = DeletedCustomers.all
    @deleted_customers = @deleted_customers.paginate( :page => params[:page], :per_page => 30)
  end
  
  def customers
    fetch_customers_per_month
    fetch_signups_per_month
    fetch_signups_per_day
#    @subscriptions = Subscription.paginate(:include => :account, :page => params[:page], :per_page => 30, :order => 'accounts.created_at desc',
#                                           :conditions => ['card_number is not null and state = ? ','active'] )
end
   
   def fetch_signups_per_day
     #@signups_per_day = Account.count(:group => "day(created_at)",:conditions => {:created_at => (30.days.ago..Time.now)}, :order => "created_at desc")
     @signups_per_day = Account.find(:all,:conditions => {:created_at => (30.days.ago..Time.now)}, :order => "created_at desc").group_by {|a| a.created_at.at_beginning_of_day}
   end
   
   def fetch_signups_per_month
     @signups_by_month = Account.count(:group => "DATE_FORMAT(created_at, '%b, %Y')", :order => "created_at desc")
   end
  
  def fetch_customers_per_month
    @customers_by_month = {}
    SubscriptionPayment.minimum(:created_at,:group => :account_id, :order => "created_at desc").each do |account_id,date|
      count = @customers_by_month.fetch(date.strftime("%b, %Y"),0)
      @customers_by_month.store(date.strftime("%b, %Y"),count+1)
    end
   @customers_by_month =  @customers_by_month.sort { |k,v| k[0].to_i <=> v[0].to_i }
  end
  
  #"name","full_domain","name","email","created_at","next_renewal_at","amount","agent_limit","subscription_plan_id","renewal_period","subscription_discount_id"
  def customers_csv
   subscriptions = Subscription.find(:all,:include => :account, :order => 'accounts.created_at desc',
                                           :conditions => {:state => 'active'} )
    csv_string = FasterCSV.generate do |csv| 
      # header row 
      csv << ["name","full_domain","contact name","email","created_at","next_renewal_at","amount","agent_limit","plan","renewal_period","discount"] 
 
      # data rows 
      subscriptions.each do |sub|
        account = sub.account
        user = account.account_admin
        discount_name = "#{sub.discount.name} ($#{sub.discount.amount} per agent)" if sub.discount
        csv << [account.name, account.full_domain, user.name,user.email,account.created_at.strftime('%Y-%m-%d'),sub.next_renewal_at.strftime('%Y-%m-%d'),sub.amount,sub.agent_limit,
                sub.subscription_plan.name,sub.renewal_period,discount_name ||= 'NULL'] 
      end 
    end 
 
    # send it to the browsah
    send_data csv_string, 
            :type => 'text/csv; charset=utf-8; header=present', 
            :disposition => "attachment; filename=customers.csv" 
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
