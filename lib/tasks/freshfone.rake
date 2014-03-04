namespace :freshfone do

	desc "Calculate costs for failed freshfone calls in the last 4 hours"
	task :failed_costs => :environment do
		Sharding.execute_on_all_shards do
			Account.active_accounts.each do |account| 
				if account.features?(:freshfone)
					account.freshfone_calls.find_failed_calls(9.hours.ago .. 3.hours.ago).each do |call|
						call.calculate_cost
					end
				end
			end
		end
	end
	
	desc "Freshfone account suspension reminder: 15 days to go"
	task :suspension_reminder_15days => :environment do
		Sharding.execute_on_all_shards do
			Freshfone::Account.find_due(15.days.from_now).each do |freshfone_account|
				account = freshfone_account.account
				FreshfoneNotifier.deliver_account_expiring(account, "15 days")
			end
		end
	end

	desc "Freshfone account suspension reminder: 3 days to go"
	task :suspension_reminder_3days => :environment do
		Sharding.execute_on_all_shards do
			Freshfone::Account.find_due(3.days.from_now).each do |freshfone_account|
				account = freshfone_account.account
				FreshfoneNotifier.deliver_account_expiring(account, "3 days")
			end
		end
	end

	desc "Trial account number deletion reminder on insufficient balance"
	task :trial_account_renewal_reminder => :environment do
		Sharding.execute_on_all_shards do
			Freshfone::Number.find_trial_account_due(3.days.from_now).each do |trial_number|
				if trial_number.insufficient_renewal_amount?
					account = trial_number.account
					FreshfoneNotifier.deliver_trial_number_expiring(account, trial_number.number, "3 days")	
				end
			end
		end
	end

	desc "Freshfone account suspension"
	task :suspend => :environment do
		Sharding.execute_on_all_shards do
			Freshfone::Account.find_due.each do |account|
				account.process_subscription
				#should we collect negative balance amounts here?
			end
		end
	end

	desc "Freshfone Number renewal"
	task :renew_numbers => :environment do
		Sharding.execute_on_all_shards do
			Freshfone::Number.find_due.each do |number|
		    number.renew
		  end
		end
	end

	#Cleanup Accounts if they are left suspended for 2 months. 
  #Two months because the released numbers are kept in recycling state by Twilio only for 
  #two months after which they are released permanently.
  desc "Freshfone abandoned accounts cleanup "
	task :close_accounts => :environment do
		Sharding.execute_on_all_shards do
			Freshfone::Account.find_due(2.months.ago).each do |account|
		  	account.close
		  end	
		end
	end

end