class SubscriptionAdmin::FreshfoneStatsController < ApplicationController
  include AdminControllerMethods
  def index
    @calls = cumulative_result(Sharding.run_on_all_slaves { ActiveRecord::Base.connection.execute(live_calls) })
    @payments = cumulative_result(Sharding.run_on_all_slaves { ActiveRecord::Base.connection.execute(freshfone_payments) })
    @signups = cumulative_result(Sharding.run_on_all_slaves { ActiveRecord::Base.connection.execute(freshfone_signups) })
  end

  private
    def live_calls
      #INTERVAL 4 HOUR
      "SELECT accounts.id, accounts.name, count(freshfone_calls.id) AS 'active_calls' 
      FROM freshfone_calls 
      JOIN accounts ON freshfone_calls.account_id = accounts.id 
      WHERE freshfone_calls.call_status = 0 AND freshfone_calls.created_at >= DATE_SUB(NOW(), INTERVAL 4 HOUR) 
      GROUP BY freshfone_calls.account_id 
      ORDER BY active_calls DESC LIMIT 10"
    end

    def freshfone_payments
      #INTERVAL 1 DAY
      "SELECT accounts.id, accounts.name, 
      freshfone_payments.purchased_credit AS 'credits', freshfone_payments.created_at
      FROM freshfone_payments 
      JOIN accounts ON freshfone_payments.account_id = accounts.id 
      WHERE freshfone_payments.created_at >= DATE_SUB(NOW(), INTERVAL 1 DAY) 
      ORDER BY freshfone_payments.created_at DESC LIMIT 10"
    end

    def freshfone_signups
      #INTERVAL 1 DAY
      "SELECT accounts.id, accounts.name, freshfone_accounts.created_at
      FROM freshfone_accounts
      JOIN accounts ON freshfone_accounts.account_id = accounts.id 
      WHERE freshfone_accounts.created_at >= DATE_SUB(NOW(), INTERVAL 1 DAY) 
      ORDER BY freshfone_accounts.created_at DESC LIMIT 10"
    end

    def cumulative_result(resultset, total_result = [])
      resultset.each do |results|
        results.each do |result|
          total_result << result
        end
      end
      total_result
    end
end