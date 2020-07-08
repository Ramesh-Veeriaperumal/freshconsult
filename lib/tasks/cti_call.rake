namespace :cti_call do

  desc "Polling the sqs to create tickets for unsuccessful screen pops"
  task :create_ticket => :environment do
    include Integrations::CtiHelper
    AwsWrapper::SqsV2.poll(SQS[:cti_call_queue], wait_time_seconds: 15) do |sqs_msg|
      msg = JSON.parse(sqs_msg.body)
      puts "** Got ** #{msg} **"
      begin
        Sharding.select_shard_of(msg['account_id']) do
          account = Account.find(msg['account_id'])
          account.make_current
          cti_call = account.cti_calls.find(msg['id'])
          link_call_to_new_ticket(cti_call) if cti_call.present? && cti_call.status == Integrations::CtiCall::NONE
        end
      rescue Exception => e
        Rails.logger.error "Problem in creating ticket for call #{msg['id']} in account #{msg['account_id']}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in creating ticket for call msg['id'] in account msg['account_id']. \n#{e.message}", :account_id => msg['account_id']}})
      ensure
        Account.reset_current_account
      end
      puts "** Done ** #{msg} **"
    end
  end
end
