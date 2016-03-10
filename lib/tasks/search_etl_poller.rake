# Not sure if we can keep here or move to ETL stack.
#
namespace :search_v2 do

  poller_comment = <<-DESC
    - Important Note
      * SQS Polling will happen incessantly and index to ES
  DESC

  task :etl_poller => :environment do
    puts '='*100, poller_comment, '='*100

    AwsWrapper::SqsV2.poll(SQS[:search_etl_queue]) do |msg|
      begin
        search_message = JSON.parse(msg.body)
        args = search_message["#{search_message['object']}_properties"].merge({
          'version' => (search_message['action_epoch'] * 1000000).ceil
        })

        puts "\n", search_message.inspect, "\n"

        # # Account + Create => EnableSearch
        # # Account + Destroy => DisableSearch
        # # Object + Destroy => DocumentRemove
        # # Object + Upsert => DocumentAdd

        case args['action']
        when 'destroy'
          if (search_message['object'] == 'account')
            Search::V2::Operations::DisableSearch.new(args).perform
          else
            set_current_account(args['account_id']) do
              Search::V2::Operations::DocumentRemove.new(args).perform
            end
          end
        else
          if (search_message['object'] == 'account')
            set_current_account(args['document_id']) do
              Search::V2::Operations::EnableSearch.new(args).perform
            end
          else
            set_current_account(args['account_id']) do
              Search::V2::Operations::DocumentAdd.new(args).perform
            end
          end
        end
      rescue => e
        puts e.message, e.backtrace.first
      end
    end

  end
end

def set_current_account(account_id, &block)
  Sharding.select_shard_of(account_id) do
    Sharding.run_on_slave do
      begin
        Account.reset_current_account
        a = Account.find(account_id).make_current
        yield
      ensure
        Account.reset_current_account
      end
    end
  end
end