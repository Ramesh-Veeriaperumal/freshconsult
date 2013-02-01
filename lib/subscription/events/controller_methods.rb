module Subscription::Events::ControllerMethods

  def event_stats(events, date)
    events.inject({}) { |h, (k, v)| h[k] = SubscriptionEvent.list_accounts(
                                                date["period(2i)"], date["period(1i)"], v); h }
  end

  def revenue_stats(events, date)
    events.inject({}) { |h, (k, v)| h[k] = SubscriptionEvent.monthly_revenue(
                                                date["period(2i)"], date["period(1i)"], v); h }
  end

  def overall_revenue(metrics, date)
    metrics.inject({}) { |h, (k, v)| h[k] = SubscriptionEvent.overall_monthly_revenue(
                                                date["period(2i)"], date["period(1i)"], v); h }
  end  
    
  #CSV
  def export_to_csv
    csv_string = FasterCSV.generate do |csv|
      csv << csv_columns

      params[:data].each do |event_id|
        event = SubscriptionEvent.find(event_id)
        
        csv << account_details(event).concat(subscription_info(event))
      end  
    end
        
    send_data csv_string, 
        :type => 'text/csv; charset=utf-8; header=present', 
        :disposition => "attachment; filename=#{params[:title]}.csv" 
  end

  private 
  
    def csv_columns
      [ "name", "full_domain", "created_at", "admin_name", "admin_email", 
        "monthly_revenue", "plan", "renewal_period", "total_agents", "free_agents", 
        "affiliate_id", "discount" ]
    end

    def account_details(event)
      event.account ? account_info(event.account) :
                deleted_account_info(DeletedCustomers.find_by_account_id(event.account_id))
    end

    def account_info(account)
      [ account.name, account.full_domain, account.created_at.strftime('%Y-%m-%d'),
        account.account_admin.name, account.account_admin.email ]
    end

    def deleted_account_info(account)
      [ account.full_domain.split(%r \(|\) ).first, account.full_domain.split(%r \(|\) ).last,
        account.account_info[:account_created_on].strftime('%Y-%m-%d'), account.admin_name, 
        account.admin_email ]
    end

    def subscription_info(event)
      [ event.cmrr, plan_name(event), event.renewal_period, event.total_agents, 
        event.free_agents, event.subscription_affiliate_id, discount_name(event) ]
    end

    def plan_name(event)
      SubscriptionPlan.find(event.subscription_plan_id).name
    end

    def discount_name(event)
      discount_id = event.subscription_discount_id
      discount = SubscriptionDiscount.find(discount_id) if discount_id 
      
      %(#{discount.name} ($#{discount.amount} / agent)) if discount
    end

end