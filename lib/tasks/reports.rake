namespace :reports do

  ###### NO ACTIVITY EVENT ######

  desc "Build a no activity entry in reports ETL for handling backlog tickets"
  task :build_no_activity => :environment do
    Reports::BuildNoActivity.new.execute_task
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
      user_id = message["user_id"]
      begin
        Sharding.select_shard_of(account_id) do
          account = Account.find_by_id(account_id)
          user = User.find_by_id(user_id)
          if (account && user)
            account.make_current
            user.make_current
            if (message['scheduled_report']!=true && export_id)
              current_export = account.data_exports.find(export_id)
              if (current_export && current_export.status == 1)
                current_export.file_created!
                list_export = HelpdeskReports::Export::TicketList.new(message)
                Sharding.run_on_slave { list_export.perform }
                current_export.completed!
              else
                puts "Duplicate Reports Ticket Export task for Account :: #{account_id} : export_id :: #{export_id}"
              end
            elsif message['scheduled_report']
              list_export = HelpdeskReports::Export::TicketList.new(message)
              Sharding.run_on_slave { list_export.perform }
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
