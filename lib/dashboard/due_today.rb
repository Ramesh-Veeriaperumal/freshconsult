class Dashboard::DueToday < Dashboard
  
  include Helpdesk::TicketFilterMethods

  attr_accessor :es_enabled, :filter_condition, :filter_type

  def initialize(es_enabled, options = {})
    @es_enabled = es_enabled
    @filter_type = "due_today"
    @filter_condition = options[:filter_options].presence || {}
  end

  def fetch_count
    action_hash = Helpdesk::Filters::CustomTicketFilter.new.default_filter(filter_type) || []
    action_hash.push({ "condition" => "responder_id", "operator" => "is_in", "value" => User.current.id}) if assigned_permission? and User.current 
    action_hash.push({ "condition" => "group_id", "operator" => "is_in", "value" => filter_condition[:group_id].to_s}) if filter_condition[:group_id].present?

    doc_count = if es_enabled
      negative_conditions = [{ 'condition' => 'status', 'operator' => 'is_not', 'value' => "#{RESOLVED},#{CLOSED}" }]
      Search::Filters::Docs.new(action_hash, negative_conditions).count(Helpdesk::Ticket)
    else
      filter_params = {:data_hash => action_hash.to_json}
      default_scoper.filter(:params => filter_params, :filter => 'Helpdesk::Filters::CustomTicketFilter').count
    end
    { :value => doc_count, :label => I18n.t("helpdesk.dashboard.summary.due_today"), :name => "due_today" }
  end
end