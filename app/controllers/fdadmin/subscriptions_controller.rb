class Fdadmin::SubscriptionsController < Fdadmin::DevopsMainController

	include Fdadmin::SubscriptionControllerMethods

  around_filter :select_slave_shard , :only => :account_subscription_info

  PAGE_LIMIT = 25

	def customer_summary
		result = {}
    result[:customer_count] = cumulative_count { Subscription.customer_count }
    result[:free_customers] = cumulative_count { Subscription.free_customers }
    result[:paying_customers] = result[:customer_count] - result[:free_customers]
    monthly_revenue = cumulative_count { Subscription.monthly_revenue }
    result[:rpu] = monthly_revenue/(result[:customer_count] - result[:free_customers])
    result[:cmrr] = monthly_revenue
    result[:paying_agents] = cumulative_count { Subscription.paid_agent_count }
    result[:free_agent] = cumulative_count { Subscription.free_agent_count }
    respond_to do |format|
    	format.json do 
    		render :json => result
    	end
    end
  end  

	def display_subscribers
		subscription_summary = {}
		subscription_summary[:subscriptions] = search(params[:search])
		respond_to do |format|
			format.json do
				render :json => subscription_summary
			end
		end
	end

  def account_subscription_info
    result = fetch_subscription_details(Subscription.find_by_account_id(params[:account_id], :include => :account))
    render :json => result
  end

	def customers
		result = {}
		result[:last_month] = fetch_signups_per_day if params[:requested_method] == "last_month"
		result[:per_month] = fetch_signups_per_month if params[:requested_method] == "per_month"
		result[:deleted] = fetch_deleted_customers if params[:requested_method] == "deleted"
		result[:customers_converted] = converted_customers_per_month if params[:requested_method] == "customers_converted"
		result[:customers] = fetch_customers_per_month if params[:requested_method] == "customers"
		respond_to do |format|
			format.json do 
				render :json => result
			end
		end
	end

	def deleted_customers
		records_to_skip = params[:page] ? params[:page].to_i * PAGE_LIMIT : 0
    deleted_customers = DeletedCustomers.where(['status not in (?)', [0]]).offset(records_to_skip).limit(PAGE_LIMIT).order("created_at DESC").all.to_a
    respond_to do |format|
    	format.json do 
    		render :json => deleted_customers 
    	end
    end
  end

  private
	def fetch_signups_per_day
    merge_array_of_hashes(Sharding.run_on_all_slaves { Account.where({:created_at => (30.days.ago..Time.now.end_of_day)}).order('created_at desc').group("DATE_FORMAT(created_at, '%d %M, %Y')").count })
  end

  def fetch_signups_per_month
     signups_by_month = merge_array_of_hashes(Sharding.run_on_all_slaves {  Subscription.where('created_at is not null').order('created_at desc').group("DATE_FORMAT(created_at, '%b, %Y')").count })
     signups_by_month = signups_by_month.sort_by{|k,v| Time.parse(k)}.reverse.to_h
  end

  def fetch_customers_per_month
    customers_by_month = {}
    Sharding.run_on_all_slaves do
    SubscriptionPayment.minimum(:created_at,:group => :account_id, :order => "created_at desc").each do |account_id,date|
      count = customers_by_month.fetch(date.strftime("%b, %Y"),0)
      customers_by_month.store(date.strftime("%b, %Y"),count+1)
    end
    end
   customers_by_month = customers_by_month.sort_by{|k,v| Time.parse(k)}.reverse.to_h
 	end

 	

  def fetch_deleted_customers
  	deleted_count_hash = {}
    deleted_paid_customers = merge_array_of_hashes(Sharding.run_on_all_slaves {
                           DeletedCustomers.group("DATE_FORMAT(deleted_customers.created_at, '%b, %Y')")
                                           .order('deleted_customers.created_at desc')
                                           .joins(' INNER JOIN subscription_payments ON deleted_customers.account_id = subscription_payments.account_id')
                                           .count(:id, distinct: true) })
   
    deleted_total_customers = merge_array_of_hashes(Sharding.run_on_all_slaves { DeletedCustomers.group("DATE_FORMAT(created_at, '%b, %Y')")
                                                                                                 .order('created_at desc').count(:id, distinct: true) })

    
    deleted_count_hash[:paid] = deleted_paid_customers
    deleted_count_hash[:total] = deleted_total_customers
    return deleted_count_hash
  end

  def converted_customers_per_month
    results = Sharding.run_on_all_slaves { Account.joins(:subscription_payments).group("DATE_FORMAT(accounts.created_at,'%b %Y')").count(:id, distinct: true) }

    conv_customers_by_month = merge_array_of_hashes(results)
    conv_customers_by_month = conv_customers_by_month.sort_by{|k,v| Time.parse(k)}.reverse.to_h
  end

  def merge_array_of_hashes(arr)
    arr.inject{|date, el| date.merge( el ){|k, old_v, new_v| old_v + new_v}}
  end

  def cumulative_count(&block)
    count = 0
    Sharding.run_on_all_slaves(&block).each { |result| count+=result }
    count
  end

end
