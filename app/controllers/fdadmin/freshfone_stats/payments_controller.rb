module Fdadmin
  module FreshfoneStats
    class PaymentsController < Fdadmin::DevopsMainController
      include Fdadmin::FreshfoneStatsMethods

      around_filter :select_slave_shard, only: [:request_csv_by_account]
      before_filter :load_account, only: [:request_csv_by_account]

      def statistics(stats = {})
        stats[:payments_data] = payment_data
        stats[:signups] = signup_data

        render json: stats
      end

      def request_csv
        all_accounts_results(params[:startDate], params[:endDate])
      end

      def request_csv_by_account
        single_account_results(params[:startDate], params[:endDate])
      end

      def active_accounts_csv
        params[:export_type] = 'All active accounts'
        active_accounts = Sharding.run_on_all_slaves do
          all_active_accounts_stats
        end
        csv_values = construct_data(active_accounts)
        generate_email(csv_values, all_active_accounts_csv_columns)
      end

      private

        def payment_data
          all_credits_type(
            Sharding.run_on_all_slaves do
              ActiveRecord::Base.connection.execute(freshfone_payments)
            end
          )
        end

        def signup_data
          @signup_data = []
          Sharding.run_on_all_slaves do
            construct_signup_data(freshfone_signups)
          end
          @signup_data
        end


        def freshfone_payments
          # INTERVAL 1 DAY
          "SELECT accounts.id as 'account_id', accounts.name,
          freshfone_payments.purchased_credit AS 'credits',
          freshfone_payments.created_at, freshfone_payments.status,
          freshfone_payments.status_message, freshfone_payments.id
          FROM freshfone_payments
          JOIN accounts ON freshfone_payments.account_id = accounts.id
          JOIN subscriptions ON subscriptions.account_id = accounts.id
          AND subscriptions.state = 'active' WHERE
          freshfone_payments.created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 DAY)
          ORDER BY freshfone_payments.created_at DESC LIMIT 10"
        end

        def freshfone_signups
          Freshfone::Payment
            .not_promotional_or_refunded_credit
            .group('account_id')
            .having("MIN(created_at) > (?)
              AND MIN(created_at) < (?)",
              Time.zone.now.utc.beginning_of_day,
              Time.zone.now.utc.end_of_day)
            .order('account_id').limit(10).all
        end

        def freshfone_payments_in_date_range(start_date, end_date)
          "SELECT accounts.id, accounts.name,
          freshfone_payments.purchased_credit AS 'credits',
          freshfone_payments.status, freshfone_payments.created_at,
          freshfone_payments.status_message, freshfone_payments.id AS 'pay_id'
          FROM freshfone_payments
          JOIN accounts ON freshfone_payments.account_id = accounts.id
          JOIN subscriptions ON subscriptions.account_id = accounts.id
          AND subscriptions.state = 'active'
          WHERE freshfone_payments.created_at >= '" + start_date + "'
          AND freshfone_payments.created_at <= '" + end_date + "'
          AND (freshfone_payments.status_message
          NOT IN ('promotional', 'refunded')
          OR freshfone_payments.status_message IS NULL)
          ORDER BY freshfone_payments.created_at DESC"
        end

        def freshfone_signups_in_date_range(start_date, end_date)
          "SELECT accounts.id, accounts.name, freshfone_accounts.created_at
          FROM freshfone_accounts
          JOIN accounts ON freshfone_accounts.account_id = accounts.id
          JOIN subscriptions ON subscriptions.account_id = accounts.id
          WHERE freshfone_accounts.created_at >= '" + start_date + "'
          AND freshfone_accounts.created_at <= '" + end_date + "'
          AND subscriptions.state = 'active'
          ORDER BY freshfone_accounts.created_at DESC"
        end

        def freshfone_call_charges_in_date_range(start_date, end_date)
          "SELECT accounts.id ,accounts.name,COUNT(*),SUM(call_cost) FROM freshfone_calls
          JOIN accounts ON freshfone_calls.account_id = accounts.id
          JOIN subscriptions ON subscriptions.account_id = accounts.id
          WHERE freshfone_calls.created_at >= '" + start_date + "'
          AND freshfone_calls.created_at <= '" + end_date + "'
          AND subscriptions.state = 'active'
          GROUP BY subscriptions.account_id"
        end

        def all_active_accounts_stats
          Freshfone::Account.joins(account: [:all_freshfone_numbers, :subscription])
                            .group('accounts.id')
                            .having('SUM(freshfone_numbers.deleted = false) > 0')
                            .all
        end

        def all_accounts_results(startDate, endDate)
          case params[:export_type]
          when 'payments'
            payment_query = freshfone_payments_in_date_range(startDate, endDate)
            payment_list = get_all_payments_list(
              Sharding.run_on_all_slaves do
                ActiveRecord::Base.connection.execute(payment_query)
              end
            )
            generate_email(payment_list, payment_csv_columns)
          when 'signups'
            signup_query = freshfone_signups_in_date_range(startDate, endDate)
            signup_list  = cumulative_result(
              Sharding.run_on_all_slaves do
                ActiveRecord::Base.connection.execute(signup_query)
              end
            )
            generate_email(signup_list, signup_csv_columns)
          when 'calldetails'
            charges_query = freshfone_call_charges_in_date_range(startDate, endDate)
            call_cost_list = cumulative_result(
              Sharding.run_on_all_slaves do
                ActiveRecord::Base.connection.execute(charges_query)
              end
            )
            generate_email(call_cost_list, cost_csv_columns)
          end
        end

        def single_account_results(startDate, endDate)
          payment_conditions = ['created_at > ? and created_at < ? and
                                (status_message NOT in (?,?) or
                                status_message IS NULL)', startDate, endDate,
                                'promotional', 'refunded']
          conditions = ['created_at > ? and created_at < ?', startDate, endDate]
          case params[:export_type]
          when 'payments'
            payments = @account.freshfone_payments.where(payment_conditions)
            payment_list = single_account_payment_list(payments)
            generate_email(payment_list, payment_csv_columns)
          when 'calldetails'
            calls = @account.freshfone_calls.where(conditions)
            render json: { call_details: { count: calls.count,
                                           cost: calls.sum(:call_cost).to_s } }
          end
        end

        def get_all_payments_list(resultset, total_result = [])
          resultset.each do |results|
              results.each(:as => :hash) do |result|
                total_result << [result['id'],
                                 result['name'],
                                 result['credits'],
                                 "#{result['status']}".to_bool ? "Success" : "Failed",
                                 result['created_at'],
                                 result['status_message'],
                                 result['pay_id']]
              end
          end
          total_result
        end

        def all_credits_type(resultset)
          promotional_credits = []
          refunded_credits = []
          other_credits = []
          resultset.each do |results|
            results.each(:as => :hash) do |results|
              if results['status_message'] == 'promotional'
                promotional_credits << results
              elsif results['status_message'] == 'refunded'
                refunded_credits << results
              else
                other_credits << results
              end
            end
          end
          { payments: other_credits, 
            promotional: promotional_credits,
            refunded: refunded_credits }
        end

        def single_account_payment_list(list, payments = [])
          list.each do |payment|
            payments << [@account.id,
                         @account.name,
                         payment.purchased_credit,
                         payment.status ? 'Success' : 'Failed',
                         payment.created_at.utc,
                         payment.status_message,
                         payment.id]
          end
          payments
        end

        def construct_data(data_list)
          csv_array = []
          data_list.each do |ff_account|
              begin
                Sharding.select_shard_of ff_account.account_id do
                  Sharding.run_on_slave do
                    account = ::Account.find(ff_account.account_id)
                    next if account.blank?
                    account.make_current
                    subscription = account.subscription
                    all_numbers = account.all_freshfone_numbers.select(:deleted)
                    csv_array << [
                      account.id,
                      account.name,
                      subscription.state,
                      Freshfone::Account::STATE_REVERSE_HASH[ff_account.state],
                      all_numbers.select { |num| num.deleted.blank? }.count,
                      all_numbers.select { |num| num.deleted.present? }.count]
                  end
                end
              rescue => e
                Rails.logger.error "Exception Message :: #{e.message} \n
                    account :: #{ff_account.account_id} \n
                    Exception Stacktrace :: #{e.backtrace.join('\n\t')}"
              ensure
                ::Account.reset_current_account
              end
          end
          csv_array
        end

        def construct_signup_data(result)
          result.each do |ff_payment|
            begin
              next if ff_payment.account.blank?
                account = ff_payment.account
                account.make_current
                next if ff_payment.blank?
                @signup_data << [
                  account.id,
                  account.name,
                  account.subscription.state,
                  ff_payment.created_at.utc.strftime('%-d %b %Y') ]
            rescue => e
              Rails.logger.error "Exception Message :: #{e.message}\n
                Exception Stacktrace :: #{e.backtrace.join('\n\t')}"
            ensure
              ::Account.reset_current_account
            end
          end
        end

        def payment_csv_columns
          ['Account ID', 'Account Name', 'Credits Added', 'Status', 'Time',
           'Status_message', 'Payment Id']
        end

        def signup_csv_columns
          ['Account ID', 'FD State', 'First payment on']
        end

        def cost_csv_columns
          ['Account ID', 'Account Name', 'Calls Count', 'Call Charges']
        end

        def all_active_accounts_csv_columns
          ['Account ID', 'Account Name', 'Freshdesk State', 'Freshfone State',
           'Number of active numbers', 'Number of deleted numbers']
        end
    end
  end
end
