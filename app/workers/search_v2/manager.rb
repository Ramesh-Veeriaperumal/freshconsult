class SearchV2::Manager
  
  include Sidekiq::Worker

  sidekiq_options :queue => :es_v2_queue, :retry => 2, :failures => :exhausted
  
  class EnableSearch < SearchV2::Manager
    def perform
      SearchService::Client.new(Account.current.id).tenant_bootstrap
      
      # Push initially bootstrapped data to ES
      #
      Account.current.users.visible.find_in_batches(:batch_size => 300) do |users|
        users.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.tickets.visible.find_in_batches(:batch_size => 300) do |tickets|
        tickets.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.notes.visible.exclude_source(['meta', 'tracker']).find_in_batches(:batch_size => 300) do |notes|
        notes.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.archive_tickets.find_in_batches(:batch_size => 300) do |archive_tickets|
        archive_tickets.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.archive_notes.exclude_source('meta').find_in_batches(:batch_size => 300) do |archive_notes|
        archive_notes.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.solution_articles.visible.find_in_batches(:batch_size => 300) do |articles|
        articles.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.topics.find_in_batches(:batch_size => 300) do |topics|
        topics.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.posts.find_in_batches(:batch_size => 300) do |posts|
        posts.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.companies.find_in_batches(:batch_size => 300) do |companies|
        companies.map(&:sqs_manual_publish_without_feature_check)
      end
      Account.current.tags.find_in_batches(:batch_size => 300) do |tags|
        tags.map(&:sqs_manual_publish_without_feature_check)
      end

    end
  end
  
  class DisableSearch < SearchV2::Manager
    def perform(args)
      args.symbolize_keys!
      SearchService::Client.new(args[:account_id]).tenant_destroy
    end
  end
end