module Helpdesk::Riak::Ticket::Body

  def self.get_from_riak(key)
    object = nil
    Timeout::timeout($riak_client_timeout) {
      object = $ticket_body.get(key)
    }
    data = Helpdesk::Text::Compression.decompress(object.content.data) if object
    JSON.parse(data)
  end

  def self.store_in_riak(key,value)
    obj = $ticket_body.new(key)
    obj.content_type = "text/plain"
    obj.data = Helpdesk::Text::Compression.compress(value)
    Timeout::timeout($riak_client_timeout) {
      obj.store
    }
  end
end
