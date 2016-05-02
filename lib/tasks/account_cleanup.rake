namespace :account_cleanup do
  
  desc "This task deletes all the suspended accounts data if they remain suspended for more than 3 months" 
  task :suspended_accounts_deletion => :environment do
    Sharding.run_on_all_slaves do
        Account.find_in_batches do |accounts|
          accounts.each do |account|
            s_m = ShardMapping.find_by_account_id(account.id)
            if s_m
              shard_name = s_m.shard_name
              if (account.subscription &&  account.subscription.suspended? && account.subscription.updated_at < 3.months.ago )
                puts "Enqueuing #{account.id} to SuspendedAccountsWorker"
                AccountCleanup::SuspendedAccountsWorker.perform_async( :shard_name => shard_name, :account_id => account.id )
              end
            end
          end
        end
    end
  end
  
  desc "This task deletes the deleted ( soft delete ) and spam tickets which have not been updated for more than 30 days"
  task :delete_spam_tickets_cleanup => :environment do
    Sharding.run_on_all_slaves do
      Account.current_pod.active_accounts.find_in_batches do |accounts|
        accounts.each do |account|
          account_id = account.id
          puts "Enqueuing #{account_id} to Delete Spam Tickets Cleanup"
          AccountCleanup::DeleteSpamTicketsCleanup.perform_async( :account_id => account_id)
        end
      end
    end
  end

end
