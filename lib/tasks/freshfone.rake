namespace :freshfone do

	desc "Calculate costs for failed freshfone calls in the last 4 hours"
	task :failed_costs => :environment do
		Sharding.execute_on_all_shards do
			Account.current_pod.active_accounts.each do |account|
				next unless valid_shard?(account.id)
				if account.features?(:freshfone)
					account.freshfone_calls.unbilled.each do |call|
						call.calculate_cost
					end
				end
			end
		end
	end

  desc "Call status update for failed freshfone calls in the last 1 hours"
  task :failed_call_status_update => :environment do
    Sharding.execute_on_all_shards do
      Account.current_pod.active_accounts.each do |account|
      	next unless valid_shard?(account.id)
        if account.features?(:freshfone)
          account.freshfone_calls.calls_with_intermediate_status.each do |call|
          	Freshfone::Cron::IntermediateCallStatusUpdate.update_call_status(call, account)
        	end
      	end
    	end
		end
  end
	
	desc "Freshfone account suspension reminder: 15 days to go"
	task :suspension_reminder_15days => :environment do
		Sharding.execute_on_all_shards do
			Freshfone::Account.current_pod.find_due(15.days.from_now).each do |freshfone_account|
				next unless valid_shard?(freshfone_account.account_id)
				account = freshfone_account.account
				FreshfoneNotifier.account_expiring(account, "15 days")
			end
		end
	end

	desc "Freshfone account suspension reminder: 3 days to go"
	task :suspension_reminder_3days => :environment do
		Sharding.execute_on_all_shards do
			Freshfone::Account.current_pod.find_due(3.days.from_now).each do |freshfone_account|
				next unless valid_shard?(freshfone_account.account_id)
				account = freshfone_account.account
				FreshfoneNotifier.account_expiring(account, "3 days")
			end
		end
	end

	desc "Trial account number deletion reminder on insufficient balance"
	task :trial_account_renewal_reminder => :environment do
		Sharding.execute_on_all_shards do
			Freshfone::Number.current_pod.find_trial_account_due(3.days.from_now).each do |trial_number|
				next unless valid_shard?(trial_number.account_id)
				if trial_number.insufficient_renewal_amount?
					account = trial_number.account
					FreshfoneNotifier.trial_number_expiring(account, trial_number.number, "3 days")	
				end
			end
		end
	end

	desc "Freshfone account suspension"
	task :suspend => :environment do
		Sharding.execute_on_all_shards do
			Freshfone::Account.current_pod.find_due.each do |ff_account|
				# ff_account.process_subscription
				next unless valid_shard?(ff_account.account_id)
				account = ff_account.account
				FreshfoneNotifier.deliver_freshfone_ops_notifier(account, {
					:subject => "Phone Channel Suspended for a Month for Account :: #{account.id}",
					:message => "The Phone Channel is Suspended for a Month for Account :: #{account.id}<br>
					And its Suspended on #{1.month.ago.utc.strftime('%d-%b-%Y')}"
					})
				#should we collect negative balance amounts here?
			end
		end
	end

	desc "Freshfone Number renewal"
	task :renew_numbers => :environment do
		Sharding.execute_on_all_shards do
			Freshfone::Number.current_pod.find_due.each do |number|
				next unless valid_shard?(number.account_id)
				number.account.make_current
				number.renew
				Account.reset_current_account
		  end
		end
	end

	#Cleanup Accounts if they are left suspended for 2 months. 
  #Two months because the released numbers are kept in recycling state by Twilio only for 
  #two months after which they are released permanently.
  #Only expiring the phone channel, Twilio Subaccount will remain suspended
  desc "Freshfone abandoned accounts cleanup "
	task :close_accounts => :environment do
		Sharding.execute_on_all_shards do
			Freshfone::Account.current_pod.find_due(1.month.ago).each do |ff_account|
				next unless valid_shard?(ff_account.account_id)
				begin
					account = ff_account.account
					account.make_current
					last_call = account.freshfone_calls.last
					if last_call.blank? || last_call.created_at < 45.days.ago
						ff_account.expire
						FreshfoneNotifier.deliver_freshfone_ops_notifier(account,
							:message => "Freshfone Account Expired For Account :: #{ff_account.account_id}")
						# FreshfoneNotifier.deliver_account_closing(account) # later for notifying customer
					else
						ff_account.update_column(:expires_on, ff_account.expires_on + 15.days) # allowing 15 days grace period.
						FreshfoneNotifier.deliver_freshfone_ops_notifier(account,
							:message => "Freshfone Account Expiry Date Extended By 15 Days For Account :: #{ff_account.account_id}")
					end
				rescue Exception => e
					FreshfoneNotifier.deliver_freshfone_ops_notifier(account,
						{:subject => "Error On Expiring Freshfone Account For Account :: #{ff_account.account_id}",
						:message => "Account :: #{ff_account.account_id}<br>Exception Message :: #{e.message}<br>
						Exception Stacktrace :: #{e.backtrace.join('\n\t')}"})
				ensure
					::Account.reset_current_account
				end
			end
		end
	end

  desc "phone trial day 7"
  task :trial_day_7 => :environment do
    Sharding.execute_on_all_shards do
      Freshfone::Account.current_pod.trial_to_expire(
        7.days.ago).each do |ff_account|
        next unless valid_shard?(ff_account.account_id)
        begin
          account = ff_account.account
          account.make_current
          FreshfoneNotifier.deliver_phone_trial_half_way(account)
        rescue Exception => e
          FreshfoneNotifier.deliver_freshfone_ops_notifier(
            account,
            subject: "Exception while performing Trial Day 7 reminder :: #{ff_account.account_id}",
            message: "Account:: #{ff_account.account_id}
              <br/>Exception Message::
              #{e.message}<br/>Exception Stacktrace ::
              #{e.backtrace.join('\n\t')}")
        ensure
          ::Account.reset_current_account
        end
      end
    end
  end

  desc "phone trial to expire in 2 days"
  task :phone_trial_to_expire => :environment do
    Sharding.execute_on_all_shards do
      Freshfone::Account.current_pod.trial_to_expire.each do |ff_account|
        next unless valid_shard?(ff_account.account_id)
        begin
          account = ff_account.account
          account.make_current
          FreshfoneNotifier.deliver_phone_trial_about_to_expire(account)
        rescue Exception => e
          FreshfoneNotifier.deliver_freshfone_ops_notifier(
            account,
            subject: "Exception while performing Phone About to Expire :: #{ff_account.account_id}",
            message: "Account:: #{ff_account.account_id}
              <br/>Exception Message::
              #{e.message}<br/>Exception Stacktrace ::
              #{e.backtrace.join('\n\t')}")
        ensure
          ::Account.reset_current_account
        end
      end
    end
  end

  desc "phone trial expires today"
  task :phone_trial_expiry_reminder => :environment do
    Sharding.execute_on_all_shards do
      Freshfone::Account.current_pod.trial_due(
        1.day.from_now).each do |ff_account|
        next unless valid_shard?(ff_account.account_id)
        begin
          account = ff_account.account
          account.make_current
          FreshfoneNotifier.deliver_phone_trial_expire(account)
        rescue Exception => e
          FreshfoneNotifier.deliver_freshfone_ops_notifier(
            account,
            subject: "Exception while performing Trial Expiry Reminder :: #{ff_account.account_id}",
            message: "Account:: #{ff_account.account_id}
              <br/>Exception Message::
              #{e.message}<br/>Exception Stacktrace ::
              #{e.backtrace.join('\n\t')}")
        ensure
          ::Account.reset_current_account
        end
      end
    end
  end

  desc 'Freshfone Trial Accounts Expiry'
  task :set_phone_trial_expired => :environment do
    Sharding.execute_on_all_shards do
      Freshfone::Account.current_pod.trial_due.each do |ff_account|
        next unless valid_shard?(ff_account.account_id)
        begin
          account = ff_account.account
          account.make_current
          account.freshfone_account.trial_expire
          FreshfoneNotifier.deliver_freshfone_ops_notifier(
            account,
            message: "Phone Trial has been expired for Account :: #{ff_account.account_id}",
            recipients: ["freshfone-ops@freshdesk.com","pulkit@freshdesk.com"])
        rescue Exception => e
          FreshfoneNotifier.deliver_freshfone_ops_notifier(
            account,
            subject: "Error On Setting Trial Expire for Freshfone Trial Account For Account :: #{ff_account.account_id}",
            message: "Account :: #{ff_account.account_id}<br>Exception Message :: #{e.message}<br>Exception Stacktrace ::#{e.backtrace.join('\n\t')}")
        ensure
          ::Account.reset_current_account
        end
      end
    end
  end

  desc 'Trial Expired Numbers will be deleted reminder: 5 days to go'
  task :trial_expired_5_days_left => :environment do
    Sharding.execute_on_all_shards do
      Freshfone::Account.current_pod.find_due(
        6.days.from_now,
        Freshfone::Account::STATE_HASH[:trial_expired]).each do |ff_account|
        next unless valid_shard?(ff_account.account_id)
        begin
          account = ff_account.account
          account.make_current
          FreshfoneNotifier.deliver_trial_number_deletion_reminder(account)
        rescue Exception => e
          FreshfoneNotifier.deliver_freshfone_ops_notifier(
            account,
            subject: "Error while Sending 5 days Phone Trial reminder for Freshdesk Account :: #{ff_account.account_id}",
            message: "Account :: #{ff_account.account_id}<br>Exception Message :: #{e.message}<br>Exception Stacktrace :: #{e.backtrace.join('\n\t')}")
        ensure
          ::Account.reset_current_account
        end
      end
    end
  end

  desc 'Trial Expired Numbers will be deleted reminder : 1 day to go'
  task :trial_expired_1_day_left => :environment do
    Sharding.execute_on_all_shards do
      Freshfone::Account.current_pod.find_due(
        1.day.from_now,
        Freshfone::Account::STATE_HASH[:trial_expired]).each do |ff_account|
        next unless valid_shard?(ff_account.account_id)
        begin
          account = ff_account.account
          account.make_current
          FreshfoneNotifier.deliver_trial_number_deletion_reminder_last_day(account)
        rescue Exception => e
          FreshfoneNotifier.deliver_freshfone_ops_notifier(
            account,
            subject: "Error while Sending 1 day to go Phone Trial Number deletion reminder for Freshdesk Account :: #{ff_account.account_id}",
            message: "Account :: #{ff_account.account_id}<br> Exception Message :: #{e.message}<br>Exception Stacktrace :: #{e.backtrace.join('\n\t')}")
        ensure
          ::Account.reset_current_account
        end
      end
    end
  end

  desc 'Expire Trial expired Freshfone Accounts'
  task :expire_trial_expired_accounts => :environment do
    Sharding.execute_on_all_shards do
      Freshfone::Account.current_pod.find_due(
        Time.zone.now,
        Freshfone::Account::STATE_HASH[:trial_expired]).each do |ff_account|
        next unless valid_shard?(ff_account.account_id)
        begin
          account = ff_account.account
          next if account.blank?
          account.make_current
          ff_account.expire
          account.features.freshfone_onboarding.destroy if account.features?(
            :freshfone_onboarding)
          FreshfoneNotifier.deliver_freshfone_ops_notifier(
            account, message: "Numbers Deleted on Trial Expired Phone Account :: #{ff_account.account_id}", recipients: ["freshfone-ops@freshdesk.com","pulkit@freshdesk.com"])
        rescue Exception => e
          FreshfoneNotifier.deliver_freshfone_ops_notifier(
            account,
            subject: "Error On Setting Expiry for Trial Expired Freshfone Account For Account :: #{ff_account.account_id}",
            message: "Account :: #{ff_account.account_id}<br> Exception Message :: #{e.message}<br>Exception Stacktrace :: #{e.backtrace.join('\n\t')}")
        ensure
          ::Account.reset_current_account
        end
      end
    end
  end

  desc "Delete freshfone recordings in Twilio"
  task :freshfone_call_twilio_recording_delete => :environment do
    Sharding.execute_on_all_shards do
      Rails.logger.debug "Triggering call recording delete for shard #{ActiveRecord::Base.current_shard_selection.shard}"
      Freshfone::Account.current_pod.all.each do |ff_account|
        ::Account.reset_current_account 
        next unless valid_shard?(ff_account.account_id)
        begin
          account = ff_account.account
          next if account.blank?
          account.make_current 
          Freshfone::Cron::CallRecordingAttachmentDelete.delete_twilio_recordings(account)
        rescue Exception => e
          FreshfoneNotifier.deliver_freshfone_ops_notifier(
            account,
            subject: "Error On Deleting Freshfone Recording For Account :: #{ff_account.account_id}",
            message: "Account :: #{ff_account.account_id}<br> Exception Message :: #{e.message}<br>Exception Stacktrace :: #{e.backtrace.join('\n\t')}")
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
