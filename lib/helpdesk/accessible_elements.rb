module Helpdesk::AccessibleElements

  include HelpdeskAccessMethods

  ITEMS_TO_DISPLAY = 25
  RECENT_TEMPLATES = 10

  # Current User accessible_elements for both Ticket templates and Scenario automations.

  def fetch_templates query, recent_ids = nil, size = 300, excluded_ids = nil
    options = {:model_hash => templ_asstn, :query => query, :id_data => recent_ids, 
      :excluded_ids => excluded_ids}
    visible_elmts = accessible_records(options, size)
    visible_elmts = template_hash(visible_elmts, recent_ids) if visible_elmts.present?
    visible_elmts
  end

  def accessible_scenrios
    model_hash = {:model => "VARule", :table => "va_rules", :asstn => "scn_automations", 
      :name => "ScenarioAutomation"}
    visible_elmts = accessible_records({:model_hash => model_hash, :query => ''})
  end

  private

  def accessible_records ops = {}, size = 200, sort = "raw_name"
    sort = nil if ops[:id_data]
    db_limit = size
    enclose = {:load => ops[:model_hash][:name].constantize::INCLUDE_ASSOCIATIONS_BY_CLASS, :size => size}
    visible_elmts = visible_records(ops, enclose, sort, db_limit)
    visible_elmts = sort_records(visible_elmts, ops[:model_hash][:model], ops[:id_data]) if visible_elmts.present?
    visible_elmts
  end

  def visible_records ops, enclose, sort, db_limit
    elements = accessible_from_es(ops[:model_hash][:name].constantize, enclose, default_visiblity, sort, nil, ops[:id_data], ops[:excluded_ids])
    elements = accessible_elements(current_account.send(ops[:model_hash][:asstn]),
      query_hash(ops[:model_hash][:model], ops[:model_hash][:table], ops[:query], [], db_limit)) if elements.nil?
    elements
  end

  def sort_records vis_elmts, model, recent
    vis_elmts.compact!
    vis_elmts.sort! { |a,b| a.name.downcase <=> b.name.downcase } if recent.nil?
    accessible_types(vis_elmts.map(&:id), model)
    vis_elmts
  end

  def accessible_types element_ids, model
    @access_types = current_account.accesses.select("accessible_id,access_type").where(:accessible_type => model, 
      :accessible_id => element_ids).collect {|acc| [acc.accessible_id, acc.access_type]}.to_h
  end

  def templ_asstn
    model, table  = "Helpdesk::TicketTemplate", "ticket_templates"
    {:model => model, :table => table, :asstn => table, :name => model}
  end

  def template_hash visible_elmts, recent_ids
    if recent_ids
      visible_elmts = visible_elmts.group_by(&:id)
      visible_elmts = recent_ids.map {|id| visible_elmts[id].first if visible_elmts[id]}
      visible_elmts.compact!
    end
    visible_elmts.map { |t| {:name => t.name, :id => t.id, 
        :type => (@access_types[t.id] == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]) ? 'personal' : 'shared' }}
  end
end