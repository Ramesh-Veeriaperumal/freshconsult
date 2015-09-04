namespace :reports do
  
  desc "Build a no activity entry in reports ETL for handling backlog tickets"
  task :build_no_activity => :environment do
    Sharding.run_on_all_slaves do
      Account.reset_current_account
      Account.active_accounts.find_in_batches do |accounts|
        accounts.each do |account|
          begin
            account.make_current
            next unless account.reports_enabled?
            Reports::BuildNoActivity.perform_async({:date => Time.now.utc})  
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
  
  desc "Poll the sqs to get the params for reports export"
  task :poll_sqs => :environment do
    $sqs_reports_export.poll(:initial_timeout => false, :batch_size => 10) do |sqs_msg|

      puts "** Got ** #{sqs_msg.body} **"
      message = JSON.parse(sqs_msg.body)
      account_id = message["account_id"]

      Sharding.select_shard_of(account_id) do
        Sharding.run_on_slave do
          begin
            account = Account.find_by_id(account_id)
            if account && account.make_current
              filter_params = message["filter_params"]
              export_args =  {} # Fill in the args
              HelpdeskReports::Export::Csv.new(export_args).trigger
            end
          rescue => e
            NewRelic::Agent.notice_error(e, :custom_params => {:export_params => message.to_json})
            subj_txt = "Reports Export exception for #{Account.current.id}"
            message  = "#{e.inspect}\n #{e.backtrace.join("\n")}"
            DevNotification.publish(SNS["reports_notification_topic"], subj_txt, message)
          end
        end
      end
      
      Account.reset_current_account
    end
  end
  
end
