class Dashboard::TrendCount < Dashboard
  include Helpdesk::TicketFilterMethods

  attr_accessor :es_enabled, :filter_condition, :trends, :is_agent

  DEFAULT_TREND = ["unresolved", "overdue", "due_today", "on_hold", "open", "new"]
  SCHEMA_LESS_COLUMNS = {
      :product_id => "helpdesk_schema_less_tickets.product_id"
    }
  def initialize(es_enabled, options = {})
    @es_enabled = es_enabled
    @filter_condition = options[:filter_options].presence || {}
    @trends = options[:trends] || DEFAULT_TREND
    @is_agent = options[:is_agent]
    @with_permissible = options[:with_permissible]
  end

  #this handles both es and db methods internally. Existing methods.
  def fetch_count
    if es_enabled && @trends.length > 1 && Account.current.es_msearch_enabled?
      filtered_counts
    else
      trends.inject({}) do |type, counter_type|
        type.merge!({:"#{counter_type}" => filtered_doc_count(counter_type.to_s)})
      end
    end
  end

  private

    def filtered_doc_count(filter_type)
      action_hash = build_action_hash(filter_type)
      if es_enabled
        Search::Filters::Docs.new(action_hash, negative_conditions(filter_type)).count(Helpdesk::Ticket)
      else
        filter_params = {:data_hash => action_hash.to_json}
        default_scoper.filter(:params => filter_params, :filter => 'Helpdesk::Filters::CustomTicketFilter').count
      end
    end

    def filtered_counts
      query_body = ""
      trends.each do |filter_type|
        query_params = filter_query(filter_type.to_s)
        query_body << "{}\n#{query_params}\n" if query_params
      end
      result = Search::Filters::Docs.new(query_body).bulk_count
      Hash[trends.map(&:to_sym).zip result]
    end

    def build_action_hash(filter_type)
      action_hash = default_filter?(filter_type) ? default_filter_data(filter_type) : custom_filter_data(filter_type)

      filter_condition.each do |filter_key, filter_value|
        action_hash.push({ "condition" => filter_key.eql?(:product_id) ? SCHEMA_LESS_COLUMNS[filter_key] : filter_key, "operator" => "is_in", "value" => filter_value.join(",")})  if filter_value.present?
      end
      action_hash.push({ "condition" => "responder_id", "operator" => "is_in", "value" => User.current.id}) if is_agent
      action_hash
    end

    def filter_query(filter_type)
      action_hash = build_action_hash(filter_type)
      Search::Filters::Docs.new(action_hash, negative_conditions(filter_type), @with_permissible).payload_params.to_json
    end

    def custom_filter_data(filter_type)
      ticket_filter = Account.current.ticket_filters.find_by_id(filter_type)
      return ticket_filter ? ticket_filter.data[:data_hash] : []
    end

    def default_filter_data(filter_type)
      Helpdesk::Filters::CustomTicketFilter.new.default_filter(filter_type.to_s) || []
    end

    def negative_conditions(filter_type)
      # Only unresolved tickets are queried for default filters
      default_filter?(filter_type) ? [{ 'condition' => 'status', 'operator' => 'is_not', 'value' => "#{RESOLVED},#{CLOSED}" }] : []
    end

    def default_filter?(filter_type)
      filter_type.to_i == 0
    end
end

# ----- Sample calls -----
#  Dashboard::TrendCount.new(false,{:filter_options => {:group_id => [1,2]}}).fetch_count
# Dashboard::TrendCount.new(false,{:filter_options => {:group_id => [1,3], :product_id => [1,2]}}).fetch_count
# Dashboard::TrendCount.new(false).fetch_count
