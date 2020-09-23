module Fdadmin
  module FreshfoneStats
    class Fdadmin::FreshfoneStats::RenewalController < Fdadmin::DevopsMainController
      include Fdadmin::FreshfoneStatsMethods

      around_filter :select_slave_shard, only: [:renewal_backlog_csv_by_account,
                                                :failed_renewal_csv_by_account]
      before_filter :load_account, only: [:renewal_backlog_csv_by_account,
                                          :failed_renewal_csv_by_account]
      before_filter :validate_freshfone_account, only: [:renewal_backlog_csv_by_account,
                                                        :failed_renewal_csv_by_account]
      def renewal_backlog_csv
        params[:export_type] = 'Renewal Backlog'
        backlog_list = cumulative_result(
          Sharding.run_on_all_slaves do
            ActiveRecord::Base.connection.execute(all_renewal_backlog)
          end
        )
        generate_email(backlog_list, renewal_backlog_csv_columns)
      end

      def renewal_backlog_csv_by_account(backlog_list = [])
        params[:export_type] = "Renewal Backlog for Account ::#{params[:account_id]}"
        ff_account = @account.freshfone_account
        if ff_account.suspended? && ff_account.expires_on.present?
          renewal_backlog_condition = ['action_type=? and created_at >= ?',
                                       Freshfone::OtherCharge::ACTION_TYPE_HASH[:number_renew],
                                       ff_account.updated_at]
          backlog = @account.freshfone_other_charges
                            .where(renewal_backlog_condition)
                            .group('freshfone_number_id').sum('debit_payment')
          backlog_list = single_account_renewal_backlog(backlog)
        end
        generate_email(backlog_list, renewal_backlog_by_account_csv_columns)
      end

      def failed_renewal_csv
        params[:export_type] = 'Failed Renewal'
        failed_renewal_list = cumulative_result(
          Sharding.run_on_all_slaves do
            ActiveRecord::Base.connection.execute(all_failed_renewal)
          end
        )
        generate_email(failed_renewal_list, failed_renewal_csv_columns)
      end

      def failed_renewal_csv_by_account(failed_renewal_list = [])
        params[:export_type] = "Failed Renewal for Account ::#{params[:account_id]}"
        ff_account = @account.freshfone_account
        if ff_account.suspended? || ff_account.active?
          failed_renewal_numbers = @account.freshfone_numbers
                                           .where(['next_renewal_at <= ?',
                                                   Time.zone.now.to_s(:db)])
          failed_renewal_list = single_account_failed_renewal(failed_renewal_numbers)
        end
        generate_email(failed_renewal_list, failed_renewal_by_account_csv_columns)
      end

      private

      def all_renewal_backlog
        "SELECT accounts.id, accounts.name,
        SUM(freshfone_other_charges.debit_payment) FROM freshfone_accounts
        JOIN accounts ON freshfone_accounts.account_id = accounts.id AND
        freshfone_accounts.state = #{Freshfone::Account::STATE_HASH[:suspended]}
        JOIN freshfone_other_charges
        ON freshfone_other_charges.account_id = accounts.id
        WHERE freshfone_accounts.expires_on > UTC_TIMESTAMP() AND
        freshfone_other_charges.action_type = #{Freshfone::OtherCharge::ACTION_TYPE_HASH[:number_renew]}
        AND freshfone_other_charges.created_at >= freshfone_accounts.updated_at GROUP BY accounts.id DESC"
      end

      def all_failed_renewal
        "SELECT accounts.id, accounts.name, count(freshfone_numbers.number)
        FROM freshfone_numbers JOIN accounts
        ON freshfone_numbers.account_id = accounts.id JOIN freshfone_accounts
        ON freshfone_accounts.account_id = accounts.id
        AND freshfone_accounts.state
        IN (#{Freshfone::Account::STATE_HASH[:suspended]},
        #{Freshfone::Account::STATE_HASH[:active]})
        WHERE freshfone_numbers.next_renewal_at <= UTC_TIMESTAMP()
        AND freshfone_numbers.deleted = false
        GROUP BY accounts.id DESC"
      end

      def single_account_renewal_backlog(list, ff_list = [])
        list.each do |ff|
          ff_list << [@account.id,
                      @account.name,
                      @account.freshfone_numbers.find(ff.first).number,
                      ff.second]
        end
        ff_list
      end

      def single_account_failed_renewal(list, ff_list = [])
        list.each do |ff|
          ff_list << [@account.id,
                      @account.name,
                      ff.id,
                      ff.number,
                      ff.next_renewal_at]
        end
        ff_list
      end

      def renewal_backlog_csv_columns
        ['Account ID', 'Account Name', 'Backlog Amount']
      end

      def failed_renewal_csv_columns
        ['Account ID', 'Account Name', 'Failed Renewal Count']
      end

      def renewal_backlog_by_account_csv_columns
        ['Account ID', 'Account Name', 'Freshfone Number', 'Backlog Amount']
      end

      def failed_renewal_by_account_csv_columns
        ['Account ID', 'Account Name', 'Freshfone Number ID',
         'Freshfone Number', 'Last Renewal Date']
      end
    end
  end
end
