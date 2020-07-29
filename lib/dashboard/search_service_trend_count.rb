class Dashboard::SearchServiceTrendCount < Dashboards

  include Search::Dashboard::QueryHelper
  include ApiDashboardConstants

  TRANSFORM_DEFAULT_FIELDS = ["shared_by_me","shared_with_me"]
  COUNT_SEARCH_DOCUMENTS = ["ticketanalytics"]
  COUNT_SEARCH_CONTEXT = "ticketDashboard"
  AGGREGATION_ERROR_RESPONSE = {"total" => -1, "results" => []}
  MULTI_AGGREGATION_ERROR_RESPONSE = {"total" => 0, "results" => []}

  def initialize(options={})
    @filter_condition = options[:filter_options].presence || options[:filter_condition] || {}
    @trends = options[:trends] || []
    @group_by = options[:group_by]
    @include_missing = options[:include_missing]
    @agg_options = options[:agg_options]
    @limit = options[:limit] || options[:limit_option]
    @is_agent = options[:is_agent]
    @with_permissible = options[:with_permissible] != false
    @errors = []
    @tag_errors = []
  end

  def fetch_count(params = {})
    Time.use_zone(Account.current.time_zone) do
      queries = params.present? ? transform_fields(params)  : construct_filter_query_es
      queries = construct_trends_query(queries) if @trends.present?
      if queries.is_a?(String)
        aggregation(queries)
      else
        multi_aggregation(queries)
      end
    end
  rescue => e
    Rails.logger.error("SearchServiceCountCluster Error :: #{e.inspect} :: #{e.backtrace[0..15]}")
    NewRelic::Agent.notice_error(e)
  end

  # For scorecard/barchart multiqueries  similar to msearch in elasticsearch
  def multi_aggregation(queries)
    query_contexts = []
    Rails.logger.info "Queries input :: #{queries}"
    if Account.current.launched?(:dashboard_java_fql_performance_fix)
      queries.each_with_index do |query, index|
        context = get_context(index, query.blank?, 'freshquery' => query, 'params' => {})
        query_contexts << context
      end
    else
      mapping = Freshquery::Mappings.get('ticketanalytics')
      visitor_mapping = Freshquery::Parser::TermVisitor.new(mapping)
      queries.each_with_index do |query, index|
        @response = get_es_query(query, visitor_mapping)
        context = get_context(index, false, 'params' => { 'filter' => '' })
        query_contexts << context
      end
    end
    result = SearchService::Client.new(Account.current.id).multi_aggregate(JSON.dump('query_contexts' => query_contexts)).records
    return result unless @errors.present?
    log_error(query_contexts)
    modify_error_tags_response(result)
  end

  #For unresolved widget and ticket list page single queries similar to search in elasticsearch
  def aggregation(query)
    @response = get_es_query(query, false)
    context = get_context('', query.blank?, Account.current.launched?(:dashboard_java_fql_performance_fix) ? { 'freshquery' => query, 'params' => {} } : { 'params' => { 'filter' => '' } })
    if @errors.present?
      log_error(query)
      return AGGREGATION_ERROR_RESPONSE
    end
    if @group_by.present?
      group = []
      group << group_by_field(@group_by.first, @include_missing) 
      group << group_by_field(@group_by.last, false) 
      context["group_by"]  = group
    end
    SearchService::Client.new(Account.current.id).aggregate(JSON.dump(context)).records
  end

  private

  def construct_trends_query(filter_query)
    queries = []
    @trends.map(&:to_s).each do |trend|
      query = default_filter?(trend) ? Helpdesk::Filters::CustomTicketFilter.new.default_filter_for_es_search(trend.to_s) : transform_fields(custom_filter_data(trend.to_i))
      query = transform_fields(query) if TRANSFORM_DEFAULT_FIELDS.include?(trend)
      query = filter_query + " AND " + query if filter_query.present?
      query = query + " AND " + construct_query_for_restricted if default_filter?(trend) and @with_permissible and User.current.agent? and User.current.restricted?
      query = query + " AND agent_id:#{User.current.id}" if default_filter?(trend) and @is_agent
      queries << query
    end
    queries
  end

  def get_context(tag = '', blank_query = false, query = {})
    context = { 'documents' => COUNT_SEARCH_DOCUMENTS, 'context' => COUNT_SEARCH_CONTEXT }.merge(query)
    context["tag"]= (@trends[tag] || tag).to_s if tag.present?
    if @agg_options.present?
      context["group_by"] = [group_by_field(@agg_options[tag.to_i]["group_by_field"][1], true, @limit) ]
      context["tag"] = tag.to_s
    end
    return context if Account.current.launched?(:dashboard_java_fql_performance_fix)

    if @response.present? && @response.valid?
      context['params']['filter'] = decode_values(JSON.dump(@response.terms)) # Hack to handle special characters ' " \ in query
    elsif !blank_query # adding this condition for if query blank need to get full ticket count
      @errors << "Error in forming ES Query in FQL in count cluster #{@response.inspect} :: tag :: #{tag.to_s}"
      @tag_errors << "#{tag.to_s}" if tag.present?
    end
    context
  end

  def get_es_query(query, visitor_mapping)
    symbolised_query = query.to_sym
    if Account.current.query_from_singleton_enabled? && DEFAULT_QUERIES.key?(symbolised_query)
      default_query = Freshquery::DefaultQueries.instance_variable_get(:"@#{DEFAULT_QUERIES[symbolised_query]}")
      return default_query unless default_query.nil?

      assign_query(query, visitor_mapping)
    else
      get_query(query, visitor_mapping)
    end
  end

  def assign_query(query, visitor_mapping)
    default_query = get_query(query, visitor_mapping)
    # for queries in DEFAULT_QUERIES, es_query has to be common accross all the accounts. Hence storing in an
    # instance variable of a singleton class and reusing them
    Freshquery::DefaultQueries.instance_variable_set(:"@#{DEFAULT_QUERIES[query.to_sym]}", default_query)
    default_query
  end

  def get_query(query, visitor_mapping)
    Freshquery::Runner.instance.construct_es_query('ticketanalytics', JSON.dump(query), visitor_mapping)
  end

  def custom_filter_data(filter_type)
      ticket_filter = Account.current.ticket_filters.find_by_id(filter_type)
      ticket_filter ? ticket_filter.data[:data_hash] : []
  end

  def default_filter?(filter_type)
      filter_type.to_i == 0
  end

  #debugging error conditions
  def log_error(query)
    Rails.logger.debug "Error in new count cluster read for query :: #{query.inspect}"
    @errors.each do |error|
      Rails.logger.debug error
    end
  end

  #handling invalid query tags 
  def modify_error_tags_response response
    @tag_errors.each do |tag|
      response["results"][tag] = MULTI_AGGREGATION_ERROR_RESPONSE
    end
    response
  end
end
