module Fdadmin
  module FreshfoneStats
    class PhoneNumberController < Fdadmin::DevopsMainController
      include Fdadmin::FreshfoneStatsMethods
      around_filter :select_slave_shard, only: [:deleted_freshfone_csv_by_account,
                                                :all_freshfone_number_csv,
                                                :purchased_numbers_csv_by_account]
      before_filter :load_account, only: [:deleted_freshfone_csv_by_account,
                                          :all_freshfone_number_csv,
                                          :purchased_numbers_csv_by_account]
      def phone_statistics
        phone_number_stats = {}
        phone_number_stats[:total_ff] = find_total_freshfone(
          Sharding.run_on_all_slaves do
            ActiveRecord::Base.connection.execute(total_freshfone_numbers)
          end
        )
        respond_to do |format|
          format.json do
            render json: phone_number_stats
          end
        end
      end

      def deleted_freshfone_csv_by_account
        params[:export_type] = "Deleted and ported numbers for Account ::#{params[:account_id]}"
        deleted_numbers = @account.all_freshfone_numbers.where(deleted: true)
          .where(updated_at: params[:startDate]..params[:endDate])
        deleted_numbers_list = single_account_deleted_freshfone(deleted_numbers)
        generate_email(deleted_numbers_list, deleted_ff_csv_columns)
      end

      def deleted_freshfone_csv
        params[:export_type] = 'Deleted and ported numbers'
        deleted_ff_query = freshfone_numbers_deleted_in_date_range(params[:startDate], params[:endDate])
        deleted_ff_list = cumulative_result(
          Sharding.run_on_all_slaves do
            ActiveRecord::Base.connection.execute(deleted_ff_query)
          end
        )
        generate_email(deleted_ff_list, all_deleted_ff_csv_columns)
      end

      def purchased_numbers_csv_by_account
        params[:export_type] = "Recently bought numbers for Account ::#{params[:account_id]}"
        recent_numbers = numbers_purchased_within_date_range(@account)
        purchased_numbers_in_range = purchased_numbers_list(recent_numbers)
        generate_email(purchased_numbers_in_range, csv_columns_for_account)
      end

      def purchased_numbers_csv
        params[:export_type] = "Recently bought numbers"
        csv_string = all_accounts_purchased_numbers_csv
        return render json: { empty: true } if csv_string.blank?
        email_csv(csv_string, params)
        render json: { status: true }
      end

      def all_freshfone_number_csv
        params[:export_type] = "numbers for Account :: #{params['account_id']}"
        all_freshfone_numbers = @account.freshfone_numbers
        freshfone_numbers_list = all_freshfone_numbers_list(all_freshfone_numbers)
        generate_email(freshfone_numbers_list, ff_csv_columns)
      end

      private

      def total_freshfone_numbers
        "SELECT count(*) AS 'count' FROM freshfone_numbers
        WHERE freshfone_numbers.deleted = FALSE"
      end

      def freshfone_numbers_deleted_in_date_range(start_date, end_date)
        "SELECT accounts.id, accounts.name,
        count(freshfone_numbers.number) - count(port), count(port)
        FROM freshfone_numbers JOIN accounts
        ON freshfone_numbers.account_id = accounts.id
        WHERE freshfone_numbers.deleted = TRUE
        AND freshfone_numbers.updated_at >= '" + start_date + "'
        AND freshfone_numbers.updated_at <= '" + end_date + "'
        GROUP BY accounts.id DESC"
      end

      def find_total_freshfone(resultset, total = 0)
        resultset.each do |results|
          results.each do |result|
            result.each do |count|
              total += count
            end
          end
        end
        total
      end

      def single_account_deleted_freshfone(list, ff_list = [])
        list.each do |ff|
          ff_list << [@account.id,
                      @account.name,
                      ff.number,
                      ff.updated_at,
                      ff.port ==  Freshfone::Number::PORT_STATE[:port_away] ? "Port away" : "Deleted"]
        end
        ff_list
      end

      def all_freshfone_numbers_list(list, ff_numbers = [])
        list.each do |ff|
            ff_numbers << [ff.id,
                           ff.account_id,
                           ff.number,
                           ff.display_number,
                           ff.country,
                           ff.region,
                           ff.state ==  Freshfone::Number::STATE[:active] ? "Active" : "Expired" ,
                           ff.next_renewal_at,
                           ff.created_at]
        end
        ff_numbers
      end

      def purchased_numbers_list(list, ff_list = [])
        list.each do |ff|
          ff_list << [@account.id,
                      @account.name,
                      ff.number,
                      ff.created_at.utc.strftime('%-d %b %Y')]
        end
        ff_list
      end

      def all_accounts_purchased_numbers_csv
        CSVBridge.generate do |csv_data|
          csv_data << all_recent_ff_csv_columns
          Sharding.run_on_all_slaves do
            prepare_csv_data(csv_data)
          end
        end
      end

      def account_ids_and_count_hash
        Freshfone::Number
          .where(created_at: params[:startDate]..params[:endDate])
          .group(:account_id)
          .count
      end

      def prepare_csv_data(csv_data)
        account_ids_and_count_hash.keys.each do |account_id|
          begin
            Sharding.select_shard_of(account_id) do
              account = ::Account.find account_id
              account.make_current

              csv_data << [
                account.id, account.name,
                account_ids_and_count_hash[account_id]
              ]
            end
          rescue => e
            Rails.logger.error "Exception Message :: #{e.message}\n
              Exception Stacktrace :: #{e.backtrace.join('\n\t')}"
          ensure
            ::Account.reset_current_account
          end
        end
      end

      def numbers_purchased_within_date_range(account)
        account.all_freshfone_numbers.where(created_at:
          params[:startDate]..params[:endDate])
      end

      def deleted_ff_csv_columns
        ['Account ID', 'Account Name', 'Freshfone Number', 'Time', 'Status']
      end

      def all_deleted_ff_csv_columns
        ['Account ID', 'Account Name', 'Freshfone Number Count',
         'Port Away Count']
      end

      def ff_csv_columns
        ['Number ID', 'Account ID', 'Number', 'Display Number', 'Country',
         'Region', 'State', 'Next Renewal', 'Created At']
      end

      def csv_columns_for_account
        ['Account ID', 'Account Name', 'Freshfone Number', 'Added At']
      end

      def all_recent_ff_csv_columns
        ['Account ID', 'Account Name', 'Added Count']
      end
    end
  end
end
