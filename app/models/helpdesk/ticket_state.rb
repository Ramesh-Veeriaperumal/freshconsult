class Helpdesk::TicketState <  ActiveRecord::Base

  include Reports::TicketStats
  include RedisKeys

  # Attributes for populating data into monthly stats tables
  STATS_ATTRIBUTES = [:resolved_at,:first_assigned_at,:assigned_at,:opened_at]

  belongs_to_account
  set_table_name "helpdesk_ticket_states"
  belongs_to :tickets , :class_name =>'Helpdesk::Ticket',:foreign_key =>'ticket_id'
  
  attr_protected :ticket_id

  before_update :update_ticket_state_changes
  after_commit_on_create :create_ticket_stats, :if => :ent_reports_enabled?
  after_commit_on_update :update_ticket_stats, :if => :ent_reports_enabled?
  
  def reset_tkt_states
    @resolved_time_was = self.resolved_at_was
    self.resolved_at = nil
    self.closed_at = nil
    self.resolution_time_by_bhrs = nil
  end

  def resolved_time_was
    @resolved_time_was ||= resolved_at
  end
  
  def set_resolved_at_state
    self.resolved_at=Time.zone.now
    set_resolution_time_by_bhrs
  end
  
  def set_closed_at_state
    set_resolved_at_state if resolved_at.nil?
    self.closed_at=Time.zone.now
  end
  
  def need_attention
    first_response_time.blank? or (requester_responded_at && agent_responded_at && requester_responded_at > agent_responded_at)
  end
  
  def is_new?
    first_response_time.blank?
  end

  def customer_responded?
    (requester_responded_at && agent_responded_at && requester_responded_at > agent_responded_at)
  end

  def first_call_resolution?
      (inbound_count == 1)
  end

  def current_state

    if (closed_at && status_updated_at && status_updated_at > closed_at) #inapportune case
        return TICKET_LIST_VIEW_STATES[:resolved_at] if(resolved_at && resolved_at > closed_at )
        return TICKET_LIST_VIEW_STATES[:created_at] if(agent_responded_at.nil?)
        return TICKET_LIST_VIEW_STATES[:agent_responded_at] 
    end

    return TICKET_LIST_VIEW_STATES[:closed_at] if closed_at
    
    if (resolved_at && status_updated_at && status_updated_at > resolved_at) #inapportune case
      return TICKET_LIST_VIEW_STATES[:created_at] if(agent_responded_at.nil?)
      return TICKET_LIST_VIEW_STATES[:agent_responded_at] 
    end
    
    return TICKET_LIST_VIEW_STATES[:resolved_at] if resolved_at
    
    return TICKET_LIST_VIEW_STATES[:requester_responded_at] if customer_responded?
    return TICKET_LIST_VIEW_STATES[:agent_responded_at] if agent_responded_at
    return TICKET_LIST_VIEW_STATES[:created_at]
  end

  def resolved_at_dirty
    resolved_at || resolved_at_dirty_fix
  end

  def closed_at_dirty
    closed_at || closed_at_dirty_fix
  end

  def set_first_response_time(time)
    self.first_response_time ||= time
    self.first_resp_time_by_bhrs ||= Time.zone.parse(created_at.to_s).
                        business_time_until(Time.zone.parse(first_response_time.to_s))
  end

  def set_resolution_time_by_bhrs
    return unless resolved_at
    time = created_at || Time.zone.now
    self.resolution_time_by_bhrs = Time.zone.parse(time.to_s).
                        business_time_until(Time.zone.parse(resolved_at.to_s))
  end

  def set_avg_response_time
    tkt_values = tickets.notes.visible.agent_public_responses.first(
      :select => %(count(*) as outbounds, 
        round(avg(helpdesk_schema_less_notes.#{Helpdesk::SchemaLessNote.resp_time_column}), 3) as avg_resp_time, 
        round(avg(helpdesk_schema_less_notes.#{Helpdesk::SchemaLessNote.resp_time_by_bhrs_column}), 3) as avg_resp_time_bhrs))
    self.outbound_count = tkt_values.outbounds
    self.avg_response_time = tkt_values.avg_resp_time
    self.avg_response_time_by_bhrs = tkt_values.avg_resp_time_bhrs
  end

private
  TICKET_LIST_VIEW_STATES = { :created_at => "created_at", :closed_at => "closed_at", 
    :resolved_at => "resolved_at", :agent_responded_at => "agent_responded_at", 
    :requester_responded_at => "requester_responded_at" }


  def resolved_at_dirty_fix
    return nil if tickets.active?
    self.update_attribute(:resolved_at , updated_at)
    NewRelic::Agent.notice_error(Exception.new("resolved_at is nil. Ticket state id is #{id}"))
    resolved_at
  end

  def closed_at_dirty_fix
    return nil if tickets.active?
    self.update_attribute(:closed_at, updated_at)
    NewRelic::Agent.notice_error(Exception.new("closed_at is nil. Ticket state id is #{id}"))
    closed_at
  end

  def update_ticket_state_changes
    @ticket_state_changes = self.changes.clone
    @ticket_state_changes.symbolize_keys!
  end

  # populating data in monthly stats table for created and update cases
  def create_ticket_stats
    resolved_tkt, fcr_tkt, sla_tkt, created_hour, resolved_hour = 0, 0, 0, created_at.hour, "\\N"
    resolved_tkt, fcr_tkt, sla_tkt, resolved_hour  = 1, 1, 1, created_hour unless tickets.active?
    assign_tkt = first_assigned_at ? 1 : 0
    sql = %(INSERT INTO #{stats_table} (#{REPORT_STATS.join(",")}) VALUES(#{account_id},#{ticket_id},
          '#{created_at.strftime('%Y-%m-%d 00:00:00')}','#{created_hour}',
          #{resolved_hour},1,#{resolved_tkt},0,#{assign_tkt},0,#{fcr_tkt},#{sla_tkt}))
    SeamlessDatabasePool.use_master_connection do 
      connection.execute(sql)
    end
  end

  def update_ticket_stats
    return unless (@ticket_state_changes.keys & STATS_ATTRIBUTES).any?
    stats_table_name = stats_table
    datetime = updated_at.strftime('%Y-%m-%d 00:00:00')
    select_sql = %(SELECT * FROM #{stats_table_name} where ticket_id = #{ticket_id} and 
      account_id = #{account_id} and created_at = '#{datetime}' )
    SeamlessDatabasePool.use_master_connection do 
      result = connection.execute(select_sql)
      f_hash = result.fetch_hash
      f_hash.symbolize_keys! unless f_hash.nil?
      result.free
      check_and_update_ticket_stats(stats_table_name,f_hash,datetime)
    end
  end

  def check_and_update_ticket_stats(stats_table_name, field_hash, datetime)
    resolved_tkt, reopens, assign_tkt, reassigns, fcr_tkt, sla_tkt, resolved_hour, 
      update_cols = 0, 0, 0, 0, 0, 0, "\\N",[]
    
    reopen_stats = "resolved_tickets = 0,resolved_hour = \\N,fcr_tickets = 0,sla_tickets = 0"
    
    if @ticket_state_changes.key?(:resolved_at) && @ticket_state_changes[:resolved_at][0].nil?
      resolved_tkt, fcr_tkt, sla_tkt, resolved_hour = 1, (inbound_count == 1) ? 1 : 0, 
        (tickets.due_by >= resolved_at) ? 1 : 0, resolved_at.hour 

      update_cols << %(resolved_tickets = #{resolved_tkt}, resolved_hour = #{resolved_hour}, 
        fcr_tickets = #{fcr_tkt}, sla_tickets = #{sla_tkt})
    end
    
    if @ticket_state_changes.key?(:first_assigned_at) && @ticket_state_changes[:first_assigned_at][0].nil?
      assign_tkt = 1 
      update_cols << "assigned_tickets = #{assign_tkt}"
    end
    
    if (@ticket_state_changes.key?(:assigned_at) && !@ticket_state_changes[:assigned_at][0].nil?)
      reassigns = field_hash ? field_hash[:num_of_reassigns].to_i + 1 : 1
      update_cols << "num_of_reassigns = #{reassigns}"
    end
    
    if @ticket_state_changes.key?(:opened_at) 
      reopens = field_hash ? field_hash[:num_of_reopens].to_i + 1 : 1
      update_cols << %(num_of_reopens = #{reopens},#{reopen_stats})
    end
    
    if field_hash.nil?
      sql = %(INSERT INTO #{stats_table_name} (#{REPORT_STATS.join(",")}) VALUES(#{account_id},#{ticket_id},
      '#{datetime}',NULL,#{resolved_hour},0,#{resolved_tkt},#{reopens},#{assign_tkt},#{reassigns},
      #{fcr_tkt},#{sla_tkt}))
      connection.execute(sql)
      update_resolved_date_stats(reopen_stats)
    else
      return if update_cols.empty?
      sql = %(UPDATE #{stats_table_name} SET #{update_cols.join(',')} where ticket_id = #{ticket_id} and 
        account_id = #{account_id} and created_at = '#{datetime}')
      connection.execute(sql)
      update_resolved_date_stats(reopen_stats) if (
        @resolved_time_was && @resolved_time_was.strftime('%Y-%m-%d 00:00:00') != datetime)
    end
  end

  def update_resolved_date_stats(reopen_stats)
    # update the resolved action entry of the ticket on resolved_at date
    if @ticket_state_changes.key?(:opened_at) 
      stats_table_name = stats_table(@resolved_time_was)
      return unless stats_table_exists?(stats_table_name)
      update_sql = %(UPDATE #{stats_table_name} SET #{reopen_stats} where ticket_id = #{ticket_id} and 
        account_id = #{account_id} and created_at = '#{@resolved_time_was.strftime('%Y-%m-%d 00:00:00')}')
      connection.execute(update_sql)
    # Add an entry in Redis to update the archived data for resolved_at date in RedShift
      set_reports_redis_key(account_id, @resolved_time_was)
    end 
  end

  def ent_reports_enabled?
    !("false".eql?(get_key ENTERPRISE_REPORTS_ENABLED))
  end

end
