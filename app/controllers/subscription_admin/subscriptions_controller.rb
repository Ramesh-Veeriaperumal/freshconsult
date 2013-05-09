class SubscriptionAdmin::SubscriptionsController < ApplicationController
  
  DUMMY_ACCOUNTS = 2
  DUMMY_MONEY = 137.0
  DUMMY_AGENTS = 5      
  
  include ModelControllerMethods
  include AdminControllerMethods 
  
  before_filter :set_selected_tab, :only => [ :customers ]
  
  def index
    @stats = SubscriptionPayment.stats if params[:page].blank?
    @day_pass_stats = SubscriptionPayment.day_pass_stats if params[:page].blank?
    @customer_count = Subscription.customer_count - DUMMY_ACCOUNTS
    @free_customers = Subscription.free_customers
    @monthly_revenue = Subscription.monthly_revenue - DUMMY_MONEY
    @cmrr = @monthly_revenue/(@customer_count - @free_customers)
    @customer_agent_count = Subscription.paid_agent_count - DUMMY_AGENTS
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
  
  def add_day_passes
    @subscription = Subscription.find(params[:id])
    if request.post? and !params[:passes_count].blank?
      day_pass_config = @subscription.account.day_pass_config
      passes_count = params[:passes_count].to_i
      raise "Maximum 30 Day passes can be extended at a time." if passes_count > 30
      day_pass_config.update_attributes(:available_passes => (day_pass_config.available_passes +  passes_count))
      Rails.logger.info "ADDED #{passes_count} DAY PASSES FOR ACCOUNT ##{@subscription.account_id}-#{@subscription.account}"
    end
    render :action => 'show'
  end
  
  def charge
    if request.post? && !params[:amount].blank?
      load_object
      if @subscription.misc_charge(params[:amount].to_f)
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

  def fetch_deleted_customers
    @deleted_paid_customers = DeletedCustomers.count(:id,:distinct => true,
                           :group => "DATE_FORMAT(deleted_customers.created_at, '%b, %Y')", 
                           :order => "deleted_customers.created_at desc", 
                           :joins => " INNER JOIN subscription_payments ON deleted_customers.account_id = subscription_payments.account_id")
   
    @deleted_total_customers = DeletedCustomers.count(:id,:distinct => true,
                           :group => "DATE_FORMAT(created_at, '%b, %Y')", 
                           :order => "created_at desc")

  end
  
  def customers
    fetch_customers_per_month
    fetch_signups_per_month
    fetch_signups_per_day
    converted_customers_per_month
    fetch_deleted_customers
  end
   
   def fetch_signups_per_day
     @signups_per_day = Account.count(:group => "DATE_FORMAT(created_at, '%d %M, %Y')",:conditions => {:created_at => (30.days.ago..Time.now.end_of_day)}, :order => "created_at desc")
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
   @customers_by_month =  @customers_by_month.sort { |k,v| Time.parse(k[0]).to_i <=> Time.parse(v[0]).to_i }
 end
   
   def converted_customers_per_month
    @conv_customers_by_month = Account.count(:id,:distinct => true,
                                                 :joins => :subscription_payments,
                                                 :group => "DATE_FORMAT(accounts.created_at,'%b %Y')")
    
    @conv_customers_by_month =  @conv_customers_by_month.sort { |k,v| Time.parse(k[0]).to_i <=> Time.parse(v[0]).to_i }
  end
  
  #"name","full_domain","name","email","created_at","next_renewal_at","amount","agent_limit","subscription_plan_id","renewal_period","subscription_discount_id"
  def customers_csv
   #subscriptions = Subscription.find(:all,:include => :account, :order => 'accounts.created_at desc',:conditions => {:state => 'active'} )
    csv_string = CSVBridge.generate do |csv| 
      # header row 
      csv << ["name","full_domain","contact name","email","created_at","next_renewal_at","amount","agent_limit","plan","renewal_period","Free agents"] 
 
      # data rows 
    Subscription.find_in_batches(:include => :account,:batch_size => 300,
                                           :conditions => [ "state != 'trial'"] ) do |subscriptions|
      subscriptions.each do |sub|
        account = sub.account
        user = account.account_admin
        csv << [account.name, account.full_domain, user.name,user.email,account.created_at.strftime('%Y-%m-%d'),sub.next_renewal_at.strftime('%Y-%m-%d'),sub.amount,sub.agent_limit,
                sub.subscription_plan.name,sub.renewal_period,
                sub.free_agents] 
      end 
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
      subscriptions = Subscription.find(:all,:include => :account,
                   :joins => "INNER JOIN accounts on accounts.id = subscriptions.account_id ",
                   :conditions => ['full_domain LIKE ?', "%#{search}%"]) 
      user_subscriptions = Subscription.find(:all,
                   :joins => "INNER JOIN users on users.account_id = subscriptions.account_id and users.user_role = 4 ",
                   :conditions => ['users.email LIKE ?', "%#{search}%"]) 
      subscriptions =  subscriptions.concat(user_subscriptions) unless user_subscriptions.nil?
      subscriptions.uniq
    else
      Subscription.find(:all,:include => :account, :order => 'created_at desc')
    end
  end
    
    def redirect_url
      action_name == 'destroy' ? { :action => 'index'} : [:admin, @subscription]
    end
  
  def set_selected_tab
     @selected_tab = :customers
  end
  
end
