namespace :account_cleanup do
  
  desc "This task deletes all the suspended accounts data if they remain suspended for more than 3 months" 
  task :suspended_accounts_deletion => :environment do
    skip_accounts = []
    Sharding.run_on_all_slaves do
        Account.find_in_batches do |accounts|
          accounts.each do |account|
            s_m = ShardMapping.find_by_account_id(account.id)
            if s_m.shard_name == ActiveRecord::Base.current_shard_selection.shard
              shard_name = s_m.shard_name
              if (account.subscription && account.subscription.suspended? && account.subscription.updated_at < 12.months.ago)
                puts "Enqueuing #{account.id} to SuspendedAccountsWorker"
                unless skip_accounts.include?(account.id)
                  AccountCleanup::SuspendedAccountsWorker.perform_async( :shard_name => shard_name, :account_id => account.id )
                end
              end
            end
          end
        end
    end
  end
  
  desc "This task deletes the deleted ( soft delete ) and spam tickets which have not been updated for more than 30 days"
  task :accounts_spam_cleanup, [:type] => :environment do |t,args|
    account_type = args.type || "trial_accounts"
    Sharding.run_on_all_slaves do
      Account.current_pod.safe_send(account_type).find_in_batches do |accounts|
        accounts.each do |account|
          account_id = account.id
          puts "#{account_type} enqueuing #{account_id} to Delete Spam Tickets Cleanup"
          AccountCleanup::DeleteSpamTicketsCleanup.perform_async( :account_id => account_id)
        end
      end
    end
  end

end
