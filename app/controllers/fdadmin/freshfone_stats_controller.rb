class Fdadmin::FreshfoneStatsController < Fdadmin::DevopsMainController
 
  around_filter :select_slave_shard , :only => :request_csv_by_account
  
  def statistics
		stats = {}
    stats[:payments] = cumulative_result(Sharding.run_on_all_slaves { ActiveRecord::Base.connection.execute(freshfone_payments) })
    stats[:signups] = cumulative_result(Sharding.run_on_all_slaves { ActiveRecord::Base.connection.execute(freshfone_signups) })
    respond_to do |format|
      format.json do
        render :json => stats
      end
    end
  end

  def request_csv
    all_accounts_results(params[:startDate],params[:endDate])
  end

  def request_csv_by_account
    single_account_results(params[:startDate],params[:endDate])
  end

  private
    def freshfone_payments
      #INTERVAL 1 DAY
      "SELECT accounts.id, accounts.name, 
      freshfone_payments.purchased_credit AS 'credits', freshfone_payments.created_at, freshfone_payments.status,
      freshfone_payments.status_message, freshfone_payments.id
      FROM freshfone_payments 
      JOIN accounts ON freshfone_payments.account_id = accounts.id 
      JOIN subscriptions ON subscriptions.account_id = accounts.id 
      WHERE freshfone_payments.created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 300 DAY) AND
      subscriptions.state = 'active' 
      ORDER BY freshfone_payments.created_at DESC LIMIT 10"
    end

    def freshfone_signups
      #INTERVAL 1 DAY
      "SELECT accounts.id, accounts.name, freshfone_accounts.created_at
      FROM freshfone_accounts
      JOIN accounts ON freshfone_accounts.account_id = accounts.id 
      JOIN subscriptions ON subscriptions.account_id = accounts.id 
      WHERE freshfone_accounts.created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 DAY) AND
      subscriptions.state = 'active' 
      ORDER BY freshfone_accounts.created_at DESC LIMIT 10"
    end

    def freshfone_payments_in_date_range(start_date,end_date)
      "SELECT accounts.id, accounts.name, 
      freshfone_payments.purchased_credit AS 'credits',freshfone_payments.status, freshfone_payments.created_at,
      freshfone_payments.status_message, freshfone_payments.id AS 'pay_id'
      FROM freshfone_payments 
      JOIN accounts ON freshfone_payments.account_id = accounts.id 
      JOIN subscriptions ON subscriptions.account_id = accounts.id 
      WHERE freshfone_payments.created_at >= '"+start_date+"' AND freshfone_payments.created_at <= '"+end_date+"'   
      AND subscriptions.state = 'active'
      ORDER BY freshfone_payments.created_at DESC"
    end

    def freshfone_signups_in_date_range(start_date,end_date)
      "SELECT accounts.id, accounts.name, freshfone_accounts.created_at
      FROM freshfone_accounts
      JOIN accounts ON freshfone_accounts.account_id = accounts.id 
      JOIN subscriptions ON subscriptions.account_id = accounts.id 
      WHERE freshfone_accounts.created_at >= '"+start_date+"' AND freshfone_accounts.created_at <= '"+end_date+"'
      AND subscriptions.state = 'active'  
      ORDER BY freshfone_accounts.created_at DESC"
    end

    def freshfone_call_charges_in_date_range(start_date,end_date)
      "SELECT accounts.id ,accounts.name,COUNT(*),SUM(call_cost) FROM freshfone_calls 
       JOIN accounts ON freshfone_calls.account_id = accounts.id 
       JOIN subscriptions ON subscriptions.account_id = accounts.id 
       WHERE freshfone_calls.created_at >= '"+start_date+"' AND freshfone_calls.created_at <= '"+end_date+"'
       AND subscriptions.state = 'active' 
       GROUP BY subscriptions.account_id"
    end

    def all_accounts_results(startDate,endDate)

      case params[:export_type]
  
        when "payments"
          payment_query = freshfone_payments_in_date_range(startDate,endDate)
          payment_list = get_all_payments_list(payment_query)
          generate_email(payment_list,payment_csv_columns)

         when "signups"
          signup_query =  freshfone_signups_in_date_range(startDate,endDate)
          signup_list  = cumulative_result(Sharding.run_on_all_slaves { ActiveRecord::Base.connection.execute(signup_query) })
          generate_email(signup_list,signup_csv_columns)

         when "calldetails"
          charges_query = freshfone_call_charges_in_date_range(startDate,endDate)
          call_cost_list  = cumulative_result(Sharding.run_on_all_slaves { ActiveRecord::Base.connection.execute(charges_query) })
          generate_email(call_cost_list,cost_csv_columns)

        end
    
    end
    
    def single_account_results(startDate, endDate)
      
      return invalid_account if account.nil?
      
      conditions = ['created_at > ? and created_at < ?', startDate, endDate]

      case params[:export_type]
      
        when "payments"
         
          payments = account.freshfone_payments.where(conditions) 
          payment_list = single_account_payment_list(payments) 
          generate_email(payment_list,payment_csv_columns)
        
        when "calldetails"  
          calls = account.freshfone_calls.where(conditions)

          render :json => {:call_details => { :count => calls.count , :cost => calls.sum(:call_cost).to_s  }}
      
      end
    
    end

    def get_all_payments_list(payment_query, total_result = [])
       Sharding.run_on_all_slaves {
        results = ActiveRecord::Base.connection.execute(payment_query)
        results.each(:as => :hash) do  |result| 
            total_result <<  [result['id'],
                              result['name'],
                              result['credits'],
                              result['status'] == 1 ? "Success": "Failed" ,
                              result['created_at'],
                              result['status_message'],
                              result['pay_id']]
                             end
      }
      total_result
    end

    def cumulative_result(resultset, total_result = [])
      resultset.each do |results|
        results.each do |result|
          total_result << result
        end
      end
      total_result
    end

    def single_account_payment_list(list, payments=[])
      list.each do |payment|
        payments << [ account.id,
                      account.name,
                      payment.purchased_credit,
                      payment.status ? "Success": "Failed" ,
                      payment.created_at.utc,
                      payment.status_message,
                      payment.id ]
       end
       payments
    end

    def account
       @account ||= Account.find_by_id(params[:account_id])     
    end

    def generate_email(list,csv_columns)
      if list.blank?
        render :json => {:empty => true} 
      else
        csv_string = generate_csv(list,csv_columns)  
        email_csv(csv_string,params)

        render :json => {:status => true}
      end 
    end

    def generate_csv(full_list,csv_columns)
      csv_string = CSVBridge.generate do |csv|
        csv << csv_columns
        list_length = full_list.length - 1
       (0..list_length).each do |index|
          csv<< full_list[index] 
        end
      end
    end

    def email_csv(csv_string, mail_params)
      FreshopsMailer.freshfone_stats_summary_csv(mail_params,csv_string)
    end

    def invalid_account
      render :json => {:status => false}
    end

    def payment_csv_columns
      [ "Account ID", "Account Name", "Credits Added", "Status", "Time","Status_message","Payment Id" ]
    end

    def signup_csv_columns
      [ "Account ID", "Account Name", "Time" ]
    end

    def cost_csv_columns
      ["Account ID", "Account Name", "Calls Count", "Call Charges"]
    end

end
