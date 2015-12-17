namespace :freshfone do

	desc "Calculate costs for failed freshfone calls in the last 4 hours"
	task :failed_costs => :environment do
		Sharding.execute_on_all_shards do
			Account.current_pod.active_accounts.each do |account| 
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
				account = freshfone_account.account
				FreshfoneNotifier.account_expiring(account, "15 days")
			end
		end
	end

	desc "Freshfone account suspension reminder: 3 days to go"
	task :suspension_reminder_3days => :environment do
		Sharding.execute_on_all_shards do
			Freshfone::Account.current_pod.find_due(3.days.from_now).each do |freshfone_account|
				account = freshfone_account.account
				FreshfoneNotifier.account_expiring(account, "3 days")
			end
		end
	end

	desc "Trial account number deletion reminder on insufficient balance"
	task :trial_account_renewal_reminder => :environment do
		Sharding.execute_on_all_shards do
			Freshfone::Number.current_pod.find_trial_account_due(3.days.from_now).each do |trial_number|
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
				number.account.make_current
				number.renew
				Account.reset_current_account
		  end
		end
	end

	#Cleanup Accounts if they are left suspended for 2 months. 
  #Two months because the released numbers are kept in recycling state by Twilio only for 
  #two months after which they are released permanently.
  desc "Freshfone abandoned accounts cleanup "
	task :close_accounts => :environment do
		Sharding.execute_on_all_shards do
			Freshfone::Account.current_pod.find_due(1.month.ago).each do |ff_account|
				begin
					account = ff_account.account
					account.make_current
					last_call = account.freshfone_calls.last
					if last_call.blank? || last_call.created_at < 45.days.ago
						ff_account.close
						FreshfoneNotifier.deliver_freshfone_ops_notifier(account,
							:message => "Freshfone Account Closed For Account :: #{ff_account.account_id}")
						# FreshfoneNotifier.deliver_account_closing(account) # later for notifying customer
					else
						ff_account.update_column(:expires_on, ff_account.expires_on + 15.days) # allowing 15 days grace period.
						FreshfoneNotifier.deliver_freshfone_ops_notifier(account,
							:message => "Freshfone Account Expiry Date Extended By 15 Days For Account :: #{ff_account.account_id}")
					end
				rescue => e
					FreshfoneNotifier.deliver_freshfone_ops_notifier(account,
						{:subject => "Error On Closing Freshfone Account For Account :: #{ff_account.account_id}",
						:message => "Account :: #{ff_account.account_id}<br>Exception Message :: #{e.message}<br>
						Exception Stacktrace :: #{e.backtrace.join('\n\t')}"})
				ensure
					::Account.reset_current_account
				end
			end
		end
	end

	desc "Delete freshfone recordings in Twilio"
	task :freshfone_call_twilio_recording_delete => :environment do
		Sharding.execute_on_all_shards do
			Freshfone::Account.current_pod.all.each do |account|
					Freshfone::Cron::CallRecordingAttachmentDelete.delete_twilio_recordings(account)
			end
		end
	end
end