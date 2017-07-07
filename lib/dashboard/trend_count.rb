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
  end

  #this handles both es and db methods internally. Existing methods.
  def fetch_count
    trends.inject({}) do |type, counter_type|
      type.merge!({:"#{counter_type}" => filtered_doc_count(counter_type)})
    end
  end

  private

    def filtered_doc_count(filter_type)
      action_hash = Helpdesk::Filters::CustomTicketFilter.new.default_filter(filter_type.to_s) || []
      
      filter_condition.each do |filter_key, filter_value|
        action_hash.push({ "condition" => filter_key.eql?(:product_id) ? SCHEMA_LESS_COLUMNS[filter_key] : filter_key, "operator" => "is_in", "value" => filter_value.join(",")})  if filter_value.present? 
      end

      action_hash.push({ "condition" => "responder_id", "operator" => "is_in", "value" => User.current.id}) if is_agent
      if es_enabled
        negative_conditions = [{ 'condition' => 'status', 'operator' => 'is_not', 'value' => "#{RESOLVED},#{CLOSED}" }]
        Search::Filters::Docs.new(action_hash, negative_conditions).count(Helpdesk::Ticket)
      else
        filter_params = {:data_hash => action_hash.to_json}
        default_scoper.filter(:params => filter_params, :filter => 'Helpdesk::Filters::CustomTicketFilter').count
      end
    end
end

# Sample calls
# Dashboard::TrendCount.new(false,{:filter_options => {:group_id => [1,2]}}).fetch_count
# Dashboard::TrendCount.new(false,{:filter_options => {:group_id => [1,3], :product_id => [1,2]}}).fetch_count
# Dashboard::TrendCount.new(false).fetch_count
