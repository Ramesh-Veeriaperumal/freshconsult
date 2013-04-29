module Subscription::Events::ControllerMethods

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