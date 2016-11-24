class Search::V2::Count::CountClient < Search::V2::Utils::EsClient

  attr_accessor :method, :path, :payload, :logger, :response, :log_data

  def initialize(method, path, query_params={}, payload=nil, log_data=nil, request_uuid=nil, account_id = nil, cluster = nil, search_type = nil)
    @method     = method.to_sym
    @path       = query_params.present? ? "#{path}?#{query_params.to_query}" : path
    @payload    = payload
    @uuid       = request_uuid
    @logger     = Search::Dashboard::CountLogger.new(@uuid)
    @log_data   = log_data
    @account_id = account_id.presence
    @cluster    = cluster.presence
    @search_type = search_type.presence
    @es_response_time = nil
    es_request
  end
end