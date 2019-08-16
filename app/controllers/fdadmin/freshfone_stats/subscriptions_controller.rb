module Fdadmin
  module FreshfoneStats
    class SubscriptionsController < Fdadmin::DevopsMainController
      include Fdadmin::FreshfoneStatsMethods

      around_filter :select_slave_shard, :only => [:stats_by_account]
      before_filter :load_account, only: [:stats_by_account]

      def stats_by_account
        result = { account_id: @account.id, account_name: @account.name }
        begin
          result[:details] = [fd_account_details, number_details, calls_usage,
            call_and_numbers_usage, ff_credit_purchase, ff_trial_start_date,
            nil, ff_trial_end_date, ff_active, onboarding_info].inject(&:merge)
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

        csv_string = subscription_csv do
          prepare_subscription_data
        end

        return render json: { empty: true } if csv_string.blank?
        email_csv(csv_string, params)
        render json: { status: true }
      end

      def recent_stats
        @csv_values = []
        Sharding.run_on_all_slaves do
          construct_data(recent_subscriptions)
        end
        respond_to do |format|
          format.json do
            render json: { subscriptions: @csv_values }
          end
        end
      end

      private

        def subscription_stats
          Freshfone::Account
            .preload(:subscription, 
              account: [:account_configuration,
                subscription: :currency])
        end

        def subscription_csv
          CSVBridge.generate do |csv_data|
            @csv_data = csv_data
            @csv_data << subscriptions_csv_columns
            Sharding.run_on_all_slaves do
              yield   
            end
          end
        end

        def prepare_subscription_data
          subscription_stats.find_in_batches(batch_size: 100) do |ff_accounts|
            ff_accounts.each do |ff_account|
              begin
                next if ff_account.account.blank?
                account = ff_account.account
                account.make_current
                first_number_created_at = account.freshfone_numbers.pluck(
                  :created_at).first
                ff_subscription = ff_account.subscription
                ff_payment = account.freshfone_payments
                        .where(status: true, status_message: nil).first
                @csv_data << [
                  account.id, account.full_domain,
                  account.admin_email,
                  account.subscription.state, account.subscription.cmrr,
                  first_number_created_at.present? ? first_number_created_at.utc.
                    strftime('%-d %b %Y') : nil,
                  get_calls_and_numbers_usage(ff_subscription),
                  ff_payment.present? ? ff_payment.created_at.utc.
                    strftime('%-d %b %Y') : nil,
                  nil,
                  get_subscription_expiry_date(ff_subscription) ].flatten
              rescue => e
                Rails.logger.error "Exception Message :: #{e.message}\n
                  Exception Stacktrace :: #{e.backtrace.join('\n\t')}"
              ensure
              ::Account.reset_current_account
              end
            end
          end
        end

        def recent_subscriptions
          Freshfone::Account
            .where(created_at: Time.zone.now.utc.beginning_of_day..
              Time.zone.now.utc.end_of_day)
            .order('created_at DESC').limit(10).all
        end

        def freshfone_account
          @freshfone_account ||= @account.freshfone_account
        end

        def freshfone_payment
          @account.freshfone_payments.where('status_message IS NULL')
            .where(status: true)
            .order('freshfone_payments.created_at DESC').first
        end

        def fd_account_details
          { account_id: @account.id, account_url: @account.full_url }
        end

        def number_details
          number = get_first_number
          return {} if number.blank?
          { fd_number_buy_date: number.created_at.utc.strftime('%-d %b %Y') }
        end

        def subscription
          @subscription ||= freshfone_account.subscription
        end

        def calls_usage
          return {} unless subscription_present?
          {
            ff_incoming_usage:
              "#{subscription.calls_usage[:minutes][:incoming]} / #{subscription.inbound[:minutes]}",
            ff_outgoing_usage:
              "#{subscription.calls_usage[:minutes][:outgoing]} / #{subscription.outbound[:minutes]}" }
        end

        def call_and_numbers_usage
          return {} unless subscription_present?
          { ff_numbers_usage: subscription.numbers_usage,
            ff_calls_usage: subscription.calls_usage[:cost].round(5).to_s }
        end

        def ff_credit_purchase
          credit_purchase_date = freshfone_payment.present? ?
            freshfone_payment.created_at.utc.strftime('%-d %b %Y') : nil
          { ff_credit_purchase_date: credit_purchase_date }
        end

        def ff_trial_start_date
          return {} unless subscription_present?
          number = get_first_number
          return {} if number.blank?
          { trial_start_date: number.created_at.utc.strftime('%-d %b %Y') }
        end

        def ff_trial_end_date
          trial_end_date = get_subscription_expiry_date(subscription
            ) if subscription_present?
          { trial_end_date: trial_end_date }
        end

        def get_first_number
          @account.freshfone_numbers.order('created_at ASC').first
        end

        def ff_active
          { active: (freshfone_account.present? && freshfone_account.active?) ||
             (@account.features?(:freshfone) && freshfone_account.blank?) }
        end

        def onboarding_info
          { onboarding_enabled:  @account.features?(:freshfone_onboarding) }
        end

        def subscription_present?
          freshfone_account.present? && subscription.present?
        end

        def subscriptions_csv_columns
          [
            'Account ID', 'Account URL', 'Account Admin Email','Freshdesk State', 'MRR',
            'First Number Bought', 'Incoming Calls(In Mins)',
            'Outgoing Calls(In Mins)', 'Calls Usage(In USD)',
            'Numbers Usage(In USD)', 'First Credit purchased Date',
            'Add On Enabled Date', 'Trial End Date'
          ]
        end

        def construct_data(data_list)
          data_list.each do |ff_account|
            begin
              next if ff_account.account.blank?
              account = ff_account.account
              account.make_current
              @csv_values << [
                account.id,
                account.name,
                account.subscription.state,
                ff_account.created_at.strftime("%d-%b-%Y")]
            rescue => e
              Rails.logger.error "Exception Message :: #{e.message}\n
                Exception Stacktrace :: #{e.backtrace.join('\n\t')}"
            ensure
              ::Account.reset_current_account
            end
          end
        end

        def get_calls_and_numbers_usage(ff_subscription)
          [ 
            ff_subscription.present? ? ff_subscription.
              calls_usage[:minutes][:incoming] : nil,
            ff_subscription.present? ? ff_subscription.
              calls_usage[:minutes][:outgoing] : nil,
            ff_subscription.present? ? ff_subscription.
              calls_usage[:cost].round(5) : nil,
            ff_subscription.present? ? ff_subscription.numbers_usage : nil
          ]
        end

        def get_subscription_expiry_date(ff_subscription)
          ff_subscription.expiry_on.utc.strftime(
            '%-d %b %Y') if ff_subscription.present?
        end

        def get_features(addon)
          addon.features.map { |f| "#{f.to_s.camelize}Feature" } if addon
        end
    end
  end
end
