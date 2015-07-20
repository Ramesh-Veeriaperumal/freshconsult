namespace :reports do
  
  task :build_no_activity => :environment do
    Sharding.run_on_all_slaves do
      Account.reset_current_account
      Account.active_accounts.find_in_batches do |accounts|
        accounts.each do |account|
          begin
            account.make_current
            Workers::Reports::BuildNoActivity.perform_async({:date => Time.now.utc})  
          rescue Exception => e
            puts e.inspect
            puts e.backtrace.join("\n")
            NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Exception in build_no_activity rake task"}})
          ensure
            Account.reset_current_account
          end
        end
      end 
    end
  end
  
end
