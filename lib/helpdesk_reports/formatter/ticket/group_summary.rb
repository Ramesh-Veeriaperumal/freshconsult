class HelpdeskReports::Formatter::Ticket::GroupSummary

  include HelpdeskReports::Util::Ticket

  attr_accessor :result

  METRICS = ["GROUP_ASSIGNED_TICKETS","GROUP_RECEIVED_TICKETS","RESOLVED_TICKETS","REOPENED_TICKETS",
             "GROUP_REASSIGNED_TICKETS","RESPONSE_SLA","RESOLUTION_SLA","FCR_TICKETS","PRIVATE_NOTES",
             "RESPONSES","AVG_FIRST_RESPONSE_TIME","AVG_RESPONSE_TIME","AVG_RESOLUTION_TIME","TICKETS_ENGAGED" ]
  def initialize data, args = {}
    @result   = data
    @args     = args
    @current  = @result['GROUP_SUMMARY_CURRENT']
    @historic = @result['GROUP_SUMMARY_HISTORIC']
    @received_tickets = @result['GROUP_SUMMARY_TICKETS_RECIEVED'] || []
  end

  def perform
    merging_current_historic_data
    removing_unscoped_and_deleted_group
    populate_result_in_summary
  end

  def merging_current_historic_data
    @current  = [] if (@current.is_a?(Hash) && @current["errors"])   || @current.empty? #Handling the edge cases
    @historic = [] if (@historic.is_a?(Hash) && @historic["errors"]) || @historic.empty?
    @received_tickets = [] if (@received_tickets.is_a?(Hash) && @received_tickets["errors"])
    @result = (@current + @historic + @received_tickets).group_by{|h| h["group_id"]}.map{ |k,v| v.reduce(:merge)}
  end

  def removing_unscoped_and_deleted_group
    @ids = []
    #Fetching result's group ids
    @result.each { |row| @ids << row["group_id"].to_i }

    @ids = @ids.flatten.uniq.compact
    scope_groups_with_agent_and_group_filter

    @group_hash = group_id_name_hash @ids
    @ids &= @group_hash.keys # Not showing result for deleted groups
  end

  def scope_groups_with_agent_and_group_filter
    if @args[:group_ids].present?
      @ids &= @args[:group_ids]
    end
    if @args[:agent_ids].present?
      scoped_ids = list_of_agent_groups
      @ids &= scoped_ids
    end
  end

  def list_of_agent_groups
    users = Account.current.users.where(helpdesk_agent: true).find_all_by_id(@args[:agent_ids], :include => :agent_groups)
    users.inject([]) do |group_ids, usr|
      group_ids |= usr.agent_groups.collect{|ag| ag.group_id}
      group_ids
    end
  end

  def group_id_name_hash ids
    Account.current.groups.find_all_by_id(ids, :select => "id, name").collect{ |g| [g.id, g.name]}.to_h
  end

  def populate_result_in_summary
    @summary = @result.select do |row|
      id = row["group_id"].to_i
      if @ids.include?(id)
        row.merge!("group_name"=>@group_hash[id])
        METRICS.each do |key|
          value    = row[key.downcase]
          row[key] = value ? value.to_i : NA_PLACEHOLDER_SUMMARY
          row.delete(key.downcase)
        end
      end
    end
    formatted_summary = []
    unless Account.current.sla_management_enabled?
      @summary.each do |s_hash|
        formatted_summary << s_hash.except(*["RESPONSE_SLA", "RESOLUTION_SLA"])
      end
      @summary = formatted_summary
    end
    @summary.sort_by{|a| a["group_name"].downcase}
  end

end
