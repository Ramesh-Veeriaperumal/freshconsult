class Fdadmin::FreshfoneSubscriptionsController < Fdadmin::DevopsMainController
	 def index
    respond_to do |format|
      format.json do
        render :json => fetch_credits_by_month
      end
    end
  end

  private
    def fetch_credits_by_month
      credits = Sharding.run_on_all_slaves { ActiveRecord::Base.connection.execute(freshfone_payments_query) }
      credits_by_month = cumulative_credits(credits)
      
    end

    def freshfone_payments_query
      "SELECT DATE_FORMAT(freshfone_payments.created_at, '%b, %Y') AS credit_month, 
        SUM(freshfone_payments.purchased_credit) AS credits FROM freshfone_payments 
        JOIN accounts ON accounts.id = freshfone_payments.account_id 
        JOIN subscriptions ON accounts.id = subscriptions.account_id 
        WHERE subscriptions.state = 'active' AND freshfone_payments.status_message IS NULL 
        GROUP BY DATE_FORMAT(freshfone_payments.created_at, '%b, %Y') 
        ORDER BY freshfone_payments.created_at DESC"
    end

    def cumulative_credits(credits, results={})
      credits.each do |credit|
        credit.each do |date, payment|
          credit = results.fetch(date,0)
          results.store(date,(credit+payment))
        end
      end
      results.sort_by{|credit| Time.parse(credit[0])}.reverse!
    end
end
