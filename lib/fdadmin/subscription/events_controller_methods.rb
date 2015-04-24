module Fdadmin::Subscription::EventsControllerMethods

  def generate_csv(events_id)
    csv_string = CSVBridge.generate do |csv|
      csv << csv_columns
      events_id.each do |event_id|
        Sharding.run_on_all_slaves do
          event = SubscriptionEvent.find_by_id(event_id)
          csv << account_details(event).concat(subscription_info(event)) unless event.blank?
        end
      end
    end
  end

  def email_csv(csv_string)
    period = DateTime.new(params[:date]["period(1i)"].to_i,params[:date]["period(2i)"].to_i).strftime("%B %Y")
    params_for_email = {:event_type => params[:event_type],:name => params[:user_name], :period => period}
    FreshopsMailer.subscription_summary_csv(params[:email],params_for_email,csv_string)
  end

  def csv_columns
    [ "name", "full_domain", "created_at", "admin_name", "admin_email", 
      "amount/month", "plan", "renewal_period", "total_agents", "free_agents", 
      "affiliate_id" ]
  end

  def account_details(event)
    event.account ? account_info(event.account) :
              deleted_account_info(DeletedCustomers.find_by_account_id(event.account_id), event.account_id)
  end

  def account_info(account)
    [ account.name, account.full_domain, account.created_at.strftime('%Y-%m-%d'),
      account.admin_first_name, account.admin_email ]
  end

  def deleted_account_info(account, account_id)
    return ["Account_id : #{account_id}", "", "", "", ""] if account.blank?
    
    [ account.full_domain.split(%r \(|\) ).first, account.full_domain.split(%r \(|\) ).last,
      account.account_info[:account_created_on].strftime('%Y-%m-%d'), account.admin_name, 
      account.admin_email ]
  end

  def subscription_info(event)
    [ event.cmrr, plan_name(event), event.renewal_period, event.total_agents, 
      event.free_agents, event.subscription_affiliate_id ]
  end

  def plan_name(event)
    SubscriptionPlan.find(event.subscription_plan_id).name
  end

end