class SearchSidekiq::BaseWorker
  include Tire::Model::Search if ES_ENABLED
  include Sidekiq::Worker

  sidekiq_options :queue => :es_index_queue, :retry => 2, :backtrace => true, :failures => :exhausted
end