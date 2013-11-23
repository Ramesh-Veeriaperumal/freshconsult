namespace :freshfone do
	
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
  #two months after which they are released completely.
  desc "Freshfone abandoned accounts cleanup "
	task :close_accounts => :environment do
		Sharding.execute_on_all_shards do
			Freshfone::Account.find_due(2.months.ago).each do |account|
		  	account.close
		  end	
		end
	end

end