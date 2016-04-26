class SearchV2::Manager
  
  include Sidekiq::Worker

  sidekiq_options :queue => :es_v2_queue, :retry => 2, :backtrace => true, :failures => :exhausted
  
  class EnableSearch < SearchV2::Manager
    def perform
      Search::V2::Tenant.new(Account.current.id).bootstrap
      
      # Push initially bootstrapped data to ES
      #
      Account.current.users.visible.find_in_batches(:batch_size => 300) do |users|
        users.map(&:sqs_manual_publish)
      end
      Account.current.tickets.visible.find_in_batches(:batch_size => 300) do |tickets|
        tickets.map(&:sqs_manual_publish)
      end
      Account.current.notes.visible.exclude_source('meta').find_in_batches(:batch_size => 300) do |notes|
        notes.map(&:sqs_manual_publish)
      end
      Account.current.archive_tickets.find_in_batches(:batch_size => 300) do |archive_tickets|
        archive_tickets.map(&:sqs_manual_publish)
      end
      Account.current.archive_notes.exclude_source('meta').find_in_batches(:batch_size => 300) do |archive_notes|
        archive_notes.map(&:sqs_manual_publish)
      end
      Account.current.solution_articles.visible.find_in_batches(:batch_size => 300) do |articles|
        articles.map(&:sqs_manual_publish)
      end
      Account.current.topics.find_in_batches(:batch_size => 300) do |topics|
        topics.map(&:sqs_manual_publish)
      end
      Account.current.posts.find_in_batches(:batch_size => 300) do |posts|
        posts.map(&:sqs_manual_publish)
      end
      Account.current.companies.find_in_batches(:batch_size => 300) do |companies|
        companies.map(&:sqs_manual_publish)
      end
      Account.current.tags.find_in_batches(:batch_size => 300) do |tags|
        tags.map(&:sqs_manual_publish)
      end

    end
  end
  
  class DisableSearch < SearchV2::Manager
    def perform(args)
      args.symbolize_keys!

      ES_V2_SUPPORTED_TYPES.keys.each do |es_type|
        Search::V2::IndexRequestHandler.new(es_type, args[:account_id], nil).remove_by_query({ account_id: args[:account_id] })
      end
      
      Search::V2::Tenant.new(args[:account_id]).rollback
    end
  end
end