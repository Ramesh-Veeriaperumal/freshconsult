# encoding: utf-8

#########################################
### Module for getting filtered count ###
###   & filtered documents from ES    ###
###  for ticket index page/dashboard  ###
#########################################

class Search::Filters::Docs
  include Search::Filters::QueryHelper

  attr_accessor :params, :negative_params

  ES_PAGINATION_SIZE = 30

  def initialize(values=[], negative_values=[])
    @params           = (values.presence || [])
    @negative_params  = (negative_values.presence || [])
  end

  # Doing this as there will be only one cluster
  def host
    (::COUNT_HOST || 'localhost:9200')
  end

  ####################
  ### READ METHODS ###
  ####################

  # Fetch count from Elasticsearch based on filters
  def count(model_class)
    response = es_request(model_class, '_search?search_type=count')
    JSON.parse(response)['hits']['total']
  end

  # Fetch docs from Elasticsearch based on filters and load from ActiveRecord
  def records(model_class, options={})
    
    # Options for querying ES
    es_offset       = ES_PAGINATION_SIZE * (options[:page].to_i - 1)
    es_defaults     = ({
                        :_source  => false, 
                        :sort     => { options[:order_entity].to_sym => options[:order_sort].to_s },
                        :size     => ES_PAGINATION_SIZE,
                        :from => es_offset 
                      })
    
    response        = es_request(model_class, '_search', es_defaults)
    
    # Get document IDs from ES response
    parsed_response = JSON.parse(response)
    record_ids      = parsed_response['hits']['hits'].collect { |record| record['_id'] }
    total_entries   = parsed_response['hits']['total']
    
    records         = model_class.constantize.where(account_id: Account.current.id, id: record_ids)
                                              .order("#{options[:order_entity]} #{options[:order_sort]}")
                                              .preload([:ticket_states, :ticket_status, :responder,:requester])
    
    # Search::Filters::Docs::Results - Wrapper for pagination
    #_Note_: Cannot do query chaining with this, as superclass is Array
    results         = Search::Filters::Docs::Results.new(records, { 
                                                                    page: options[:page].to_i, 
                                                                    from: es_offset, 
                                                                    total_entries: total_entries 
                                                                  })
    results
  end

  #####################
  ### WRITE METHODS ###
  #####################

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

    # Make request to ES to get the DOCS
    def es_request(model_class, end_point, options={})
      deserialized_params = es_query(params, negative_params).merge(options)
      error_handle do
        request = RestClient::Request.new(method: :get,
                                           url: [host, alias_name, end_point].join('/'),
                                           payload: deserialized_params.to_json)
        log_request(request)
        response = request.execute
        log_response(response)
        return response
      end
    end

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

    ############################################
    ### LOGGING & ERROR NOTIFICATION METHODS ###
    ############################################

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

  ###################################################
  ### Response wrapper with pagination attributes ###
  ###################################################

  #_Note_: Not sure if array is the right superclass. But works for now.
  class Search::Filters::Docs::Results < Array

    attr_accessor :total, :options, :records

    def initialize(result_set, es_options={})
      @total    = es_options[:total_entries]
      @options  = {
        :page   => es_options[:page] || 1,
        :from   => es_options[:from] || 0
      }
      super(result_set)
    end

    #=> Will Paginate Support(taken from Tire) <=#
    def total_entries
      @total
    end

    def per_page
      ES_PAGINATION_SIZE.to_i
    end

    def total_pages
      ( @total.to_f / per_page ).ceil
    end

    def current_page
      if @options[:page]
        @options[:page].to_i
      else
        (per_page + @options[:from].to_i) / per_page
      end
    end

    def previous_page
      current_page > 1 ? (current_page - 1) : nil
    end

    def next_page
      current_page < total_pages ? (current_page + 1) : nil
    end

    def offset
      per_page * (current_page - 1)
    end

    def out_of_bounds?
      current_page > total_pages
    end
  end
end