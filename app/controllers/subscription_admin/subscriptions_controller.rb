class SubscriptionAdmin::SubscriptionsController < ApplicationController
  
  include ModelControllerMethods
  include AdminControllerMethods 
  
  before_filter :set_selected_tab, :only => [ :customers ]
  
  def index
    @customer_count = cumilative_count { Subscription.customer_count }
    @free_customers = cumilative_count { Subscription.free_customers }
    @monthly_revenue = cumilative_count { Subscription.monthly_revenue }
    @cmrr = 0#@monthly_revenue/(@customer_count - @free_customers)
    @customer_agent_count = cumilative_count { Subscription.paid_agent_count }
    @subscriptions = search(params[:search])
    @free_agent_count = cumilative_count { Subscription.free_agent_count }
    
    @freshfone_credits = cumilative_count { SubscriptionPayment.freshfone_credits }
    @day_passes = cumilative_count { SubscriptionPayment.day_pass_purchases }
  end  
  
  def deleted_customers
    @deleted_customers = DeletedCustomers.all(:conditions =>  ['status not in (?)', [0]], 
                                              :order => "created_at DESC")
    @deleted_customers = @deleted_customers.paginate( :page => params[:page], :per_page => 30)
  end

  def fetch_deleted_customers
    @deleted_paid_customers = merge_array_of_hashes(Sharding.run_on_all_slaves { DeletedCustomers.count(:id,:distinct => true,
                           :group => "DATE_FORMAT(deleted_customers.created_at, '%b, %Y')", 
                           :order => "deleted_customers.created_at desc", 
                           :joins => " INNER JOIN subscription_payments ON deleted_customers.account_id = subscription_payments.account_id") })
   
    @deleted_total_customers = merge_array_of_hashes(Sharding.run_on_all_slaves { DeletedCustomers.count(:id,:distinct => true,
                           :group => "DATE_FORMAT(created_at, '%b, %Y')", 
                           :order => "created_at desc")})

  end
  
  def customers
    fetch_customers_per_month
    fetch_signups_per_month
    fetch_signups_per_day
    converted_customers_per_month
    fetch_deleted_customers
  end
   
   def fetch_signups_per_day
     @signups_per_day = merge_array_of_hashes(Sharding.run_on_all_slaves { Account.count(:group => "DATE_FORMAT(created_at, '%d %M, %Y')",
      :conditions => {:created_at => (30.days.ago..Time.now.end_of_day)}, :order => "created_at desc")})
   end
   
   def fetch_signups_per_month
     @signups_by_month = merge_array_of_hashes(Sharding.run_on_all_slaves {  Subscription.count(:group => "DATE_FORMAT(created_at, '%b, %Y')", 
                                       :order => "created_at desc", :conditions => "created_at is not null") })
     @signups_by_month = @signups_by_month.sort { |k,v| Time.parse(k[0]).to_i <=> Time.parse(v[0]).to_i  }.reverse
   end
  
  def fetch_customers_per_month
    @customers_by_month = {}
    Sharding.run_on_all_slaves do
    SubscriptionPayment.minimum(:created_at,:group => :account_id, :order => "created_at desc").each do |account_id,date|
      count = @customers_by_month.fetch(date.strftime("%b, %Y"),0)
      @customers_by_month.store(date.strftime("%b, %Y"),count+1)
    end
    end
   @customers_by_month =  @customers_by_month.sort { |k,v| Time.parse(k[0]).to_i <=> Time.parse(v[0]).to_i }.reverse
 end
   
   def converted_customers_per_month
    results = Sharding.run_on_all_slaves {  Account.count(:id,:distinct => true,:joins => :subscription_payments,
                                                 :group => "DATE_FORMAT(accounts.created_at,'%b %Y')") }

    @conv_customers_by_month = merge_array_of_hashes(results)
    @conv_customers_by_month =  @conv_customers_by_month.sort { |k,v| Time.parse(k[0]).to_i <=> Time.parse(v[0]).to_i }.reverse
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
        admin_name = "#{account.admin_first_name} #{account.admin_last_name}"
        csv << [account.name, account.full_domain, admin_name,account.admin_email,account.created_at.strftime('%Y-%m-%d'),sub.next_renewal_at.strftime('%Y-%m-%d'),sub.amount,sub.agent_limit,
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
    results = []
    domain_mappings = DomainMapping.find(:all, 
      :conditions => ['domain LIKE ? and portal_id IS ?', "%#{search}%", nil], :limit => 30)
    
    unless search.blank?
      domain_mappings.each do |domain|
        Sharding.admin_select_shard_of(domain.account_id) do
          Sharding.run_on_slave do
            results << Subscription.find_by_account_id(domain.account_id, :include => :account)
          end
        end
      end
    end
    results
  end
    
    def redirect_url
      action_name == 'destroy' ? { :action => 'index'} : [:admin, @subscription]
    end
  
  def set_selected_tab
     @selected_tab = :customers
  end

  def check_admin_user_privilege
      if !(current_user and current_user.has_role?(:accounts))
        flash[:notice] = "You dont have access to view this page"
        redirect_to(admin_subscription_login_path)
      end
  end 

end
