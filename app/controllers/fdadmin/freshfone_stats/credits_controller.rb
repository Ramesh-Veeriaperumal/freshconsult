module Fdadmin
  module FreshfoneStats
    class CreditsController < Fdadmin::DevopsMainController
      include Fdadmin::FreshfoneStatsMethods

      around_filter :select_slave_shard, only: [:request_csv_by_account]
      before_filter :load_account, only: [:request_csv_by_account]

      def request_csv
        all_accounts_results(params[:startDate], params[:endDate])
      end

      def request_csv_by_account
        single_account_results(params[:startDate], params[:endDate])
      end

      private

      def freshfone_credits_in_date_range(start_date, end_date, status)
        "SELECT accounts.id, accounts.name, freshfone_payments.purchased_credit
        AS credits, freshfone_payments.status, freshfone_payments.created_at
        FROM freshfone_payments JOIN accounts
        ON freshfone_payments.account_id = accounts.id
        JOIN subscriptions ON subscriptions.account_id = accounts.id
        AND subscriptions.state = 'active'
        WHERE freshfone_payments.created_at >= '" + start_date + "'
        AND freshfone_payments.created_at <= '" + end_date + "'
        AND freshfone_payments.status_message = '" + status + "'
        ORDER BY freshfone_payments.created_at DESC"
      end

      def all_accounts_results(startDate, endDate)
        case params[:export_type]
        when 'promotional-credits'
          promotional_credits_query = freshfone_credits_in_date_range(startDate, endDate, 'promotional')
          promotional_credits_list = get_all_credits_list(
            Sharding.run_on_all_slaves do
              ActiveRecord::Base.connection.execute(promotional_credits_query)
            end
          )
          generate_email(promotional_credits_list, promotional_credits_csv_columns)

        when 'refunded-credits'
          refunded_credits_query = freshfone_credits_in_date_range(startDate, endDate, 'refunded')
          refunded_credits_list = get_all_credits_list(
            Sharding.run_on_all_slaves do
              ActiveRecord::Base.connection.execute(refunded_credits_query)
            end
          )
          generate_email(refunded_credits_list, refunded_credits_csv_columns)
        end
      end

      def single_account_results(startDate, endDate)
        promotional_credits_conditions = ['created_at >= ? and created_at <= ?
                                           and status_message = ?',
                                          startDate, endDate, 'promotional']
        refunded_credits_conditions = ['created_at >= ? and created_at <= ? and
                                        status_message = ?', startDate, endDate,
                                       'refunded']
        case params[:export_type]
        when 'promotional-credits'
          promotional_credits = @account.freshfone_payments.where(promotional_credits_conditions)
          promotional_credits_list = single_account_credits_list(promotional_credits)
          generate_email(promotional_credits_list, promotional_credits_csv_columns)

        when 'refunded-credits'
          refunded_credits = @account.freshfone_payments.where(refunded_credits_conditions)
          refunded_credits_list = single_account_credits_list(refunded_credits)
          generate_email(refunded_credits_list, refunded_credits_csv_columns)
        end
      end

      def get_all_credits_list(resultset, total_result = [])
        resultset.each do |results|
          results.each(:as => :hash) do  |result| 
            total_result << [result['id'],
                             result['name'],
                             result['credits'],
                             "#{result['status']}".to_bool ? "Success" : "Failed",
                             result['created_at']]
          end
        end
        total_result
      end

      def single_account_credits_list(list, credits = [])
        list.each do |credit|
          credits << [@account.id,
                      @account.name,
                      credit.purchased_credit,
                      credit.status ? 'Success' : 'Failed',
                      credit.created_at.utc]
        end
        credits
      end

      def promotional_credits_csv_columns
        ['Account ID', 'Account Name', 'Credits Added', 'Status', 'Time']
      end

      def refunded_credits_csv_columns
        ['Account ID', 'Account Name', 'Credits Refunded', 'Status', 'Time']
      end
    end
  end
end
