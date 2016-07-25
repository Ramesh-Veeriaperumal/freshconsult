class Search::Dashboard::CountClient < Search::V2::Utils::EsClient

  attr_accessor :method, :path, :payload, :logger, :response, :log_data

  def initialize(method, path, payload=nil, log_data=nil, request_uuid=nil)
    @method     = method.to_sym
    @path       = path
    @payload    = payload
    @uuid       = request_uuid
    @logger     = Search::Dashboard::CountLogger.new(@uuid)
    @log_data   = log_data
    es_request
  end
end