class HelpdeskReports::Formatter::Ticket::AgentSummary

  include HelpdeskReports::Util::Ticket

  attr_accessor :result

  METRICS = ["AGENT_ASSIGNED_TICKETS","RESOLVED_TICKETS","REOPENED_TICKETS",
             "AGENT_REASSIGNED_TICKETS","RESPONSE_SLA","RESOLUTION_SLA",
             "FCR_TICKETS","PRIVATE_NOTES","RESPONSES","AVG_FIRST_RESPONSE_TIME",
             "AVG_RESPONSE_TIME","AVG_RESOLUTION_TIME"]

  def initialize data, args = {}
    @result   = data
    @args     = args
    @current  = @result['AGENT_SUMMARY_CURRENT']
    @historic = @result['AGENT_SUMMARY_HISTORIC']
    @csv_export = args[:csv_export]
  end

  def perform
    merging_current_historic_data
    removing_unscoped_agent
    populate_result_in_summary
  end

  def merging_current_historic_data
    @current  = [] if (@current.is_a?(Hash) && @current["errors"])   || @current.empty? #Handling the edge cases
    @historic = [] if (@historic.is_a?(Hash) && @historic["errors"]) || @historic.empty?
    @result = (@current + @historic).group_by{|h| h["agent_id"]}.map{ |k,v| v.reduce(:merge)}
  end

  def removing_unscoped_agent
    @agent_ids = []
    @agent_hash, @deleted_agent_hash = {}, {}
    @result.each { |row| @agent_ids << row["agent_id"].to_i }#Fetching result's agent ids

    @agent_ids = @agent_ids.flatten.uniq.compact
    all_ids    = @agent_ids
    
    scope_agents_with_agent_and_group_filter

    @agent_hash = agent_id_name_hash @agent_ids if @agent_ids.present?
    @agent_ids &= @agent_hash.keys

    @deleted_agent_ids  = all_ids - @agent_ids
    
    @deleted_agent_hash = deleted_agent_id_name_hash @deleted_agent_ids if @deleted_agent_ids.present?
    @deleted_agent_ids  = @deleted_agent_hash.keys
  end

  def scope_agents_with_agent_and_group_filter
    if @args[:agent_ids].present?
      @agent_ids &= @args[:agent_ids]
    end
    if @args[:group_ids].present?
      scoped_ids = list_of_group_agents
      @agent_ids &= scoped_ids
    end
  end

  def list_of_group_agents
    acc_groups = Account.current.groups_from_cache.select{|g| (@args[:group_ids] || []).include? g.id}
    acc_groups.inject([]) do |agents, group|
      agents |= group.agents.collect{|a| a.id}
    end
  end

  def agent_id_name_hash ids
    Account.current.users.where(helpdesk_agent: true).find_all_by_id(ids, :select => "id, name").collect{ |a| [a.id, a.name]}.to_h
  end

  def deleted_agent_id_name_hash ids 
     Account.current.users.unscoped.where(helpdesk_agent: false).find_all_by_id(ids, :select => "id, name").collect{ |a| [a.id, a.name]}.to_h
  end

  def populate_result_in_summary
    @summary = @result.select do |row|
        id = row["agent_id"].to_i
        if(@agent_ids.include?(id) || @deleted_agent_ids.include?(id))
          agent_name = @agent_ids.include?(id) ? @agent_hash[id] : (@csv_export ? "#{@deleted_agent_hash[id]} (deleted)" : "#{@deleted_agent_hash[id]}")
          is_deleted_agent = @deleted_agent_ids.include?(id)
          if is_deleted_agent && discard_contacts_with_only_private_note(row)
            next
          else
            row.merge!("agent_name" => agent_name, "deleted" => is_deleted_agent )
            METRICS.each do |key|
              value    = row[key.downcase]
              row[key] = value ? value.to_i : NA_PLACEHOLDER_SUMMARY
              row.delete(key.downcase)
            end
          end
        end
      end

    @summary.sort_by{|a| a["agent_name"].downcase}
  end

  def discard_contacts_with_only_private_note(agent_details)
    agent_details.select{|k,v| ["agent_id","private_notes"].exclude?(k)}.values.compact.empty?
  end

end
