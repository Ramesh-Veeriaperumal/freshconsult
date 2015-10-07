# encoding: utf-8

# Workaround for getting filtered results from ES
class Search::Filters::Docs
  include Search::Filters::QueryHelper

  attr_accessor :params

  def initialize(values=[])
    @params = (values.presence || [])
  end

  ### READ METHODS ###

  # Fetch count from Elasticsearch based on filters
  def count(model_class)
    deserialized_params = es_query(params)
    error_handle do
      request = RestClient::Request.new(method: :get,
                                         url: [host, alias_name, '_search?search_type=count'].join('/'),
                                         payload: deserialized_params.to_json)
      log_request(request)
      response = request.execute
      log_response(response)
      return JSON.parse(response)["hits"]["total"]
    end
  end

  # Doing this as there will be only one cluster
  def host
    (::COUNT_HOST || 'localhost:9200')
  end

  ### WRITE METHODS ###

  def index_document(model_class, id, version_value=1)
    error_handle do
      Time.use_zone('UTC') do
        model_object  = model_class.constantize.find_by_id(id)
        version       = {
          :version_type => 'external',
          :version      => version_value.to_i
        }
        Tire::Configuration.client.put(document_path(model_class, id, version), model_object.to_es_json)
      end
    end
  end

  def remove_document(model_class, id)
    error_handle do
      Tire::Configuration.client.delete(document_path(model_class, id))
    end
  end

  private

    #_Note_: Include type if not doing only for ticket
    def alias_name
      "es_filters_#{Account.current.id}"
    end

    def document_path(model_class, id, query_params={})
      path    = [host, alias_name, model_class.demodulize.downcase, id].join('/')
      query_params.blank? ? path : "#{path}?#{query_params.to_params}"
    end

    def error_handle(&block)
      begin
        yield
      rescue => e
        Rails.logger.error "Exception in Docs :: #{e.message}"
        NewRelic::Agent.notice_error(e)
        notify_devops(e)
      end
    end

    ### Methods to log requests ###

    def log_request(req)
      out = []
      out << "RestClient.#{req.method} #{req.url.inspect}"
      out << req.payload.inspect if req.payload
      out << req.processed_headers.to_a.sort.map { |(k, v)| [k.inspect, v.inspect].join("=>") }.join(", ")
      Rails.logger.debug(out.join(', '))
    end

    def log_response(res)
      size = (res.body.nil? ? 0 : res.body.size)
      Rails.logger.debug("# => #{res.code} #{res.class.to_s.gsub(/^Net::HTTP/, '')} | #{(res['Content-type'] || '').gsub(/;.*$/, '')} #{size} bytes\n")
    end

    def notify_devops(exception)
      return if Rails.env.development?

      notification_topic = SNS["dev_ops_notification_topic"]
      options = { :message => exception.message, :backtrace => exception.backtrace }
      DevNotification.publish(notification_topic, "Doc count exception on #{Time.now}", options.to_json)
    end
end