namespace :reports do

  ###### NO ACTIVITY EVENT ######

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

  ###### REPORT EXPORT SQS POLLER ######

  desc "Poll the sqs to get the params for reports export"
  task :poll_sqs => :environment do
    $sqs_reports_helpkit_export.poll(:initial_timeout => false, :batch_size => 10) do |sqs_msg|
      Account.reset_current_account
      puts "** Got ** #{sqs_msg.body} **"
      message    = JSON.parse(sqs_msg.body)
      account_id = message["account_id"]
      export_id  = message["export_id"]
      begin
        Sharding.select_shard_of(account_id) do
          account = Account.find_by_id(account_id)
          if account && account.make_current
            current_export = account.data_exports.find(export_id)
            if (current_export && current_export.status == 1)
              current_export.file_created!
              list_export = HelpdeskReports::Export::TicketList.new(message)
              Sharding.run_on_slave { list_export.trigger }
              current_export.completed!
            else
              puts "Duplicate Reports Ticket Export task for Account :: #{account_id} : export_id :: #{export_id}"
            end
          end
        end
      rescue => e
        NewRelic::Agent.notice_error(e, :custom_params => {:export_params => message.to_json})
        subj_txt = "Reports Export exception for #{Account.current.id}"
        message  = "#{e.inspect}\n #{e.backtrace.join("\n")}"
        puts message
        DevNotification.publish(SNS["reports_notification_topic"], subj_txt, message)
      ensure
        Account.reset_current_account
      end
    end
  end
end
