class Fdadmin::FreshfoneStatsController < Fdadmin::DevopsMainController

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

  private
    def freshfone_payments
      #INTERVAL 1 DAY
      "SELECT accounts.id, accounts.name, 
      freshfone_payments.purchased_credit AS 'credits', freshfone_payments.created_at
      FROM freshfone_payments 
      JOIN accounts ON freshfone_payments.account_id = accounts.id 
      WHERE freshfone_payments.created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 DAY) 
      ORDER BY freshfone_payments.created_at DESC LIMIT 10"
    end

    def freshfone_signups
      #INTERVAL 1 DAY
      "SELECT accounts.id, accounts.name, freshfone_accounts.created_at
      FROM freshfone_accounts
      JOIN accounts ON freshfone_accounts.account_id = accounts.id 
      WHERE freshfone_accounts.created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 DAY) 
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
