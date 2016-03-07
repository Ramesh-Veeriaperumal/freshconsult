module Fdadmin
  module FreshfoneStats
    class SubscriptionsController < Fdadmin::DevopsMainController
      include Fdadmin::FreshfoneStatsMethods

      around_filter :select_slave_shard, :only => [:stats_by_account]
      
      def stats_by_account
        result = { account_id: account.id, account_name: account.name }
        begin
          result[:details] = [fd_account_details, number_details, calls_usage,
            call_and_numbers_usage].inject(&:merge)
          result[:status] = 'success'
        rescue => e
          Rails.logger.error "Exception while fetching freshfone account details
          \n Exception message :: #{e.message}\n
          Exception Stacktrace :: #{e.backtrace.join('\n\t')}"
          result[:status] = 'error'
        ensure
          respond_to do |format|
            format.json do
              render json: result
            end
          end
        end
      end

      def stats_csv
        params[:export_type] = 'Subscriptions Stats'
        data = Sharding.run_on_all_slaves { subscription_stats }
        csv_string = construct_csv(data, subscriptions_csv_columns)
        return render json: {empty: true} if csv_string.blank?
        email_csv(csv_string,params)
        render json: {status: true}
      end

      def recent_stats
        results = Sharding.run_on_all_slaves { recent_subscriptions }
        csv_values = construct_data(results)
        respond_to do |format|
          format.json do
            render json: { subscriptions: csv_values }
          end
        end
      end

      private

        def subscription_stats
          Freshfone::Account.joins(:account, :subscription)
            .includes(
              :subscription, account: [
                { subscription: :currency },
                :account_configuration, :freshfone_numbers])
            .where('subscriptions.state != "suspended" ')
            .trial_states.group('accounts.id')
        end

        def recent_subscriptions
          Freshfone::Account.joins(:account, :subscription)
          .joins("INNER JOIN subscriptions ON subscriptions.id = accounts.id AND
            subscriptions.state != 'suspended'")
          .includes(:account)
          .trial_states
          .order('freshfone_accounts.created_at DESC').limit(10)
        end

        def freshfone_account
          @freshfone_account ||= account.freshfone_account
        end

        def fd_account_details
          { account_url: account.full_url }
        end

        def number_details
          number = account.freshfone_numbers.order('created_at ASC').first
          return {} if number.blank?
          { fd_number_buy_date: number.created_at.utc.strftime('%-d %b %Y') }
        end

        def subscription
          @subscription ||= freshfone_account.subscription
        end

        def calls_usage
          return {} unless freshfone_account.in_trial_states? &&
              subscription.present?
          {
            ff_incoming_usage:
              "#{subscription.calls_usage[:minutes][:incoming]} / #{subscription.inbound[:minutes]}",
            ff_outgoing_usage:
              "#{subscription.calls_usage[:minutes][:outgoing]} / #{subscription.outbound[:minutes]}" }
        end

        def call_and_numbers_usage
          return {} unless subscription.present?
          { ff_numbers_usage: subscription.numbers_usage,
            ff_calls_usage: subscription.calls_usage[:cost].round(5).to_s }
        end

        def subscriptions_csv_columns
          [
            'Account ID', 'Account URL', 'Account Admin Email','Freshdesk State', 'MRR',
            'First Number Bought', 'Incoming Calls(In Mins)',
            'Outgoing Calls(In Mins)', 'Calls Usage(In USD)',
            'Numbers Usage(In USD)'
          ]
        end

        def construct_csv(data_list, headers)
          return if data_list.blank?
          CSVBridge.generate do |csv_data|
            construct_csv_data(csv_data, data_list,headers)
          end
        end

        def construct_data(data_list)
          csv_array = []
          data_list.each do |ff_account|
            Sharding.select_shard_of ff_account.account_id do
              Sharding.run_on_slave do
                begin
                  next if ff_account.account.blank?
                  account = ff_account.account
                  account.make_current
                  csv_array << [
                    account.id,
                    account.name,
                    ff_account.created_at.strftime("%d-%b-%Y")]
                rescue => e
                  Rails.logger.error "Exception Message :: #{e.message}\n
                    Exception Stacktrace :: #{e.backtrace.join('\n\t')}"
                ensure
                  ::Account.reset_current_account
                end
              end
            end
          end
          csv_array
        end

        def construct_csv_data(csv_data, data_list, headers)
          csv_data << headers
          data_list.each do |ff_account|
            Sharding.select_shard_of ff_account.account_id do
              Sharding.run_on_slave do
                begin
                  next if ff_account.account.blank?
                  account = ff_account.account
                  account.make_current
                  first_number = account.freshfone_numbers.min(&:created_at)
                  ff_subscription = ff_account.subscription
                  csv_data << [
                    account.id, account.full_url,
                    account.admin_email,
                    account.subscription.state, account.subscription.cmrr,
                    first_number.present? ? first_number.created_at.utc : nil,
                    ff_subscription.calls_usage[:minutes][:incoming],
                    ff_subscription.calls_usage[:minutes][:outgoing],
                    ff_subscription.calls_usage[:cost].round(5).to_s,
                    ff_subscription.numbers_usage]
                rescue => e
                  Rails.logger.error "Exception Message :: #{e.message}\n
                    Exception Stacktrace :: #{e.backtrace.join('\n\t')}"
                ensure
                  ::Account.reset_current_account
                end
              end
            end
          end
        end
    end
  end
end
