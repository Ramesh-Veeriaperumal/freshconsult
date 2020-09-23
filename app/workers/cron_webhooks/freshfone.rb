module CronWebhooks
  class Freshfone < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_freshfone, retry: 0, dead: true, failures: :exhausted

    def perform(args)
      perform_block(args) do
        safe_send(@args[:task_name])
      end
    end

    private

      def freshfone_failed_costs
        Sharding.execute_on_all_shards do
          Account.current_pod.active_accounts.each do |account|
            next unless valid_shard?(account.id)
            next unless account.features?(:freshfone)
            account.freshfone_calls.unbilled.each(&:calculate_cost)
          end
        end
      end

      def freshfone_suspend
        Sharding.execute_on_all_shards do
          ::Freshfone::Account.current_pod.find_due.each do |ff_account|
            # ff_account.process_subscription
            next unless valid_shard?(ff_account.account_id)
            account = ff_account.account
            FreshfoneNotifier.deliver_freshfone_ops_notifier(account,
                                                             subject: "Phone Channel Suspended for a Month for Account :: #{account.id}",
                                                             message: "The Phone Channel is Suspended for a Month for Account :: #{account.id}<br>
            And its Suspended on #{1.month.ago.utc.strftime('%d-%b-%Y')}")
            # should we collect negative balance amounts here?
          end
        end
      end

      def freshfone_renew_numbers
        Sharding.execute_on_all_shards do
          ::Freshfone::Number.current_pod.find_due.each do |number|
            next unless valid_shard?(number.account_id)
            number.account.make_current
            number.renew
            Account.reset_current_account
          end
        end
      end

      def freshfone_suspension_reminder_3days
        Sharding.execute_on_all_shards do
          ::Freshfone::Account.current_pod.find_due(3.days.from_now).each do |freshfone_account|
            next unless valid_shard?(freshfone_account.account_id)
            account = freshfone_account.account
            FreshfoneNotifier.account_expiring(account, '3 days')
          end
        end
      end

      def freshfone_suspension_reminder_15days
        Sharding.execute_on_all_shards do
          ::Freshfone::Account.current_pod.find_due(15.days.from_now).each do |freshfone_account|
            next unless valid_shard?(freshfone_account.account_id)
            account = freshfone_account.account
            FreshfoneNotifier.account_expiring(account, '15 days')
          end
        end
      end

      def freshfone_freshfone_call_twilio_recording_delete
        Sharding.execute_on_all_shards do
          Rails.logger.debug "Triggering call recording delete for shard #{ActiveRecord::Base.current_shard_selection.shard}"
          ::Freshfone::Account.current_pod.all.each do |ff_account|
            ::Account.reset_current_account
            next unless valid_shard?(ff_account.account_id)
            begin
              account = ff_account.account
              next if account.blank?
              account.make_current
              ::Freshfone::Cron::CallRecordingAttachmentDelete.delete_twilio_recordings(account)
            rescue Exception => e
              FreshfoneNotifier.deliver_freshfone_ops_notifier(
                account,
                subject: "Error On Deleting Freshfone Recording For Account :: #{ff_account.account_id}",
                message: "Account :: #{ff_account.account_id}<br> Exception Message :: #{e.message}<br>Exception Stacktrace :: #{e.backtrace.join('\n\t')}"
              )
            ensure
              ::Account.reset_current_account
            end
          end
        end
      end

      def freshfone_failed_call_status_update
        Sharding.execute_on_all_shards do
          Account.current_pod.active_accounts.each do |account|
            next unless valid_shard?(account.id)
            next unless account.features?(:freshfone)
            account.freshfone_calls.calls_with_intermediate_status.each do |call|
              ::Freshfone::Cron::IntermediateCallStatusUpdate.update_call_status(call, account)
            end
          end
        end
      end

      def freshfone_failed_close_accounts
        Sharding.execute_on_all_shards do
          ::Freshfone::Account.current_pod.find_due(1.month.ago).each do |ff_account|
            next unless valid_shard?(ff_account.account_id)
            begin
              account = ff_account.account
              account.make_current
              last_call = account.freshfone_calls.last
              if last_call.blank? || last_call.created_at < 45.days.ago
                ff_account.expire
                FreshfoneNotifier.deliver_freshfone_ops_notifier(account,
                                                                 message: "Freshfone Account Expired For Account :: #{ff_account.account_id}")
                # FreshfoneNotifier.deliver_account_closing(account) # later for notifying customer
              else
                ff_account.update_column(:expires_on, ff_account.expires_on + 15.days) # allowing 15 days grace period.
                FreshfoneNotifier.deliver_freshfone_ops_notifier(account,
                                                                 message: "Freshfone Account Expiry Date Extended By 15 Days For Account :: #{ff_account.account_id}")
              end
            rescue Exception => e
              FreshfoneNotifier.deliver_freshfone_ops_notifier(account,
                                                               subject: "Error On Expiring Freshfone Account For Account :: #{ff_account.account_id}",
                                                               message: "Account :: #{ff_account.account_id}<br>Exception Message :: #{e.message}<br>
                                                              Exception Stacktrace :: #{e.backtrace.join('\n\t')}")
            ensure
              ::Account.reset_current_account
            end
          end
        end
      end

      def valid_shard?(account_id)
        shard = ShardMapping.lookup_with_account_id(account_id)
        shard.present? &&
          shard.shard_name == ActiveRecord::Base.current_shard_selection.shard
      end
  end
end
