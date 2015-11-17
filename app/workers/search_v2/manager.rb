class SearchV2::Manager
  
  include Sidekiq::Worker

  sidekiq_options :queue => :es_v2_toggle, :retry => 2, :backtrace => true, :failures => :exhausted
  
  # Register tenant details in ES on account create
  #
  class EnableSearch < SearchV2::Manager
    
    #(*) Create aliases
    #(*) Push data for ES models
    def perform
      Search::V2::Tenant.new(Account.current.id).bootstrap
      
      Account.current.users.visible.find_in_batches(:batch_size => 300) do |users|
        update_in_es(users)
      end
      Account.current.tickets.visible.find_in_batches(:batch_size => 300) do |tickets|
        update_in_es(tickets)
      end
      Account.current.solution_articles.visible.find_in_batches(:batch_size => 300) do |articles|
        update_in_es(articles)
      end
      Account.current.topics.find_in_batches(:batch_size => 300) do |topics|
        update_in_es(topics)
      end
      Account.current.companies.find_in_batches(:batch_size => 300) do |companies|
        update_in_es(companies)
      end
      Account.current.notes.visible.exclude_source('meta').find_in_batches(:batch_size => 300) do |notes|
        update_in_es(notes)
      end
      Account.current.tags.find_in_batches(:batch_size => 300) do |tags|
        update_in_es(tags)
      end
    end
    
    private
      
      def update_in_es(items)
        items.each { |item| item.send(:es_create) }
      end
  end
  
  # Deregister tenant details in ES on account destroy
  #
  class DisableSearch < SearchV2::Manager
    
    def perform(args)
      args.symbolize_keys!
      
      ES_SUPPORTED_TYPES.keys.each do |es_type|
        Search::V2::IndexRequestHandler.new(es_type, args[:account_id], nil).remove_by_query({ account_id: args[:account_id] })
      end
      
      Search::V2::Tenant.new(args[:account_id]).rollback
    end
  end
end