class Helpdesk::TicketState <  ActiveRecord::Base

  self.primary_key = :id
  self.table_name =  "helpdesk_ticket_states"

  include Reports::TicketStats
  include Redis::RedisKeys
  include Redis::ReportsRedis
  include BusinessHoursCalculation

  # Attributes for populating data into monthly stats tables
  STATS_ATTRIBUTES = ['resolved_at','first_assigned_at','assigned_at','opened_at']
  TICKET_STATE_SEARCH_FIELDS = [ 'resolved_at', 'closed_at', 'agent_responded_at',
                                 'requester_responded_at', 'status_updated_at' ]
  # Model changes for presenter includes only the listed fields
  PRESENTER_FIELDS_MAPPING = { 'first_resp_time_by_bhrs': 'first_response_by_bhrs', 'resolution_time_by_bhrs': 'time_to_resolution_in_bhrs',
                               'resolution_time_by_chrs': 'time_to_resolution_in_chrs', 'first_assigned_at': nil,
                               'closed_at': nil, 'resolved_at': nil, 'first_response_time': nil,
                               'assigned_at': nil, 'inbound_count': nil }

  alias_attribute :on_state_time, :ts_int1
  alias_attribute :custom_status_updated_at, :ts_datetime1

  belongs_to_account
  belongs_to :tickets , :class_name =>'Helpdesk::Ticket',:foreign_key =>'ticket_id'
  
  attr_protected :ticket_id

  before_update :update_ticket_state_changes
  #https://github.com/rails/rails/issues/988#issuecomment-31621550
  # after_commit :update_ticket_stats, on: :update, :if => :ent_reports_enabled?
  # after_commit :create_ticket_stats, on: :create, :if => :ent_reports_enabled?
  after_commit :update_search_index,  on: :update

  publishable on: [:update], exchange_model: :tickets, exchange_action: :update
  
  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher
  
  def reset_tkt_states
    @resolved_time_was = self.resolved_at_was
    self.resolved_at = nil
    self.closed_at = nil
    self.resolution_time_by_bhrs = nil
  end

  def resolved_time_was
    @resolved_time_was ||= resolved_at
  end
  
  def set_resolved_at_state(time=Time.zone.now)
    self.resolved_at = time 
    set_resolution_time_by_bhrs
  end
  
  def set_closed_at_state(time=Time.zone.now)
    set_resolved_at_state(self.closed_at || time) if resolved_at.nil?
    self.closed_at ||= time
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

  def customer_responded_for_outbound?
    if agent_responded_at and requester_responded_at
      requester_responded_at > agent_responded_at
    else
      requester_responded_at.present?
    end
  end

  def set_custom_status_updated_at(time=Time.zone.now)
    self.custom_status_updated_at = time
  end

  def consecutive_customer_response?
    if (agent_responded_at && requester_responded_at)
      requester_responded_at > agent_responded_at
    else
      agent_responded_at.blank?
    end
  end

  def first_call_resolution?
      (inbound_count == 1 and !tickets.outbound_email?)
  end

  def current_state(outbound_email = nil)

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
    
    if outbound_email || (outbound_email.nil? and self.tickets.outbound_email?)
      return TICKET_LIST_VIEW_STATES[:requester_responded_at] if customer_responded_for_outbound?
    else
      return TICKET_LIST_VIEW_STATES[:requester_responded_at] if customer_responded?
    end
    
    return TICKET_LIST_VIEW_STATES[:agent_responded_at] if agent_responded_at
    return TICKET_LIST_VIEW_STATES[:created_at]
  end

  def resolved_at_dirty
    resolved_at || resolved_at_dirty_fix
  end

  def closed_at_dirty
    closed_at || closed_at_dirty_fix
  end

  def pending_since_dirty
    pending_since || pending_since_dirty_fix
  end

  def set_first_response_time(time, created_time = nil)
    created_time ||= self.created_at
    self.first_response_time ||= time
    BusinessCalendar.execute(self.tickets) { 
      if self.first_resp_time_by_bhrs
        self.first_resp_time_by_bhrs
      else
        default_group = tickets.group if tickets
        self.first_resp_time_by_bhrs = calculate_time_in_bhrs(created_time, first_response_time, default_group)
      end
    }
  end

  def set_resolution_time_by_bhrs
    return unless resolved_at
    time = created_at || Time.zone.now
    BusinessCalendar.execute(self.tickets) {
      default_group = tickets.group if tickets
      self.resolution_time_by_bhrs = calculate_time_in_bhrs(time, resolved_at, default_group)
    }
  end

  def change_on_state_time(from_time, to_time, note = nil)
    priority_for_sla_calculation = tickets.priority_changed? ? tickets.priority_was : tickets.priority
    sla_policy = tickets.sla_policy || account.sla_policies.default.first
    sla_detail = sla_policy.sla_details.where(:priority => priority_for_sla_calculation).first
    if sla_detail.override_bhrs
      updated_time = (to_time - from_time).round()
    else
      BusinessCalendar.execute(self.tickets) {
        default_group = tickets.group if tickets
        updated_time = calculate_time_in_bhrs(from_time, to_time, default_group)
      }
    end
    obj = note.present? ? note : self
    log_on_state_time(from_time, to_time, sla_policy, sla_detail, updated_time, obj)
    obj.on_state_time = obj.on_state_time.to_i + updated_time
    obj.schema_less_note.save unless note.nil?
  end

  def set_avg_response_time
    tkt_values = tickets.notes.visible.agent_public_responses.first(
      :select => %(count(*) as outbounds, 
        round(avg(helpdesk_schema_less_notes.#{Helpdesk::SchemaLessNote.resp_time_column}), 3) as avg_resp_time, 
        round(avg(helpdesk_schema_less_notes.#{Helpdesk::SchemaLessNote.resp_time_by_bhrs_column}), 3) as avg_resp_time_bhrs))
    #Hack - for outbound emails, the initial description is considererd as outbound, so adding that for outbound_count column
    self.outbound_count = tickets.outbound_email? ? tkt_values.outbounds + 1 : tkt_values.outbounds
    self.avg_response_time = tkt_values.avg_resp_time
    self.avg_response_time_by_bhrs = tkt_values.avg_resp_time_bhrs
  end

  def update_search_index
    tickets.update_es_index if (@ticket_state_changes.keys & TICKET_STATE_SEARCH_FIELDS).any?
  end

  # Needed when ticket update happens via update_ticket_states_queue
  #
  def esv2_fields_updated?
    (@ticket_state_changes.keys & esv2_columns).any?
  end
  
  # To-do: Update with v2 columns
  #
  def esv2_columns
    @@esv2_columns ||= [:resolved_at, :closed_at, :agent_responded_at, :requester_responded_at, :status_updated_at].map(&:to_s)
  end

  # populating data in monthly stats table for created and update cases
  def create_ticket_stats
    begin
      resolved_tkt, fcr_tkt, sla_tkt, created_hour, resolved_hour = 0, 0, 0, created_at.hour, "\\N"
      resolved_tkt, fcr_tkt, sla_tkt, resolved_hour  = 1, 1, 1, created_hour unless tickets.active?
      assign_tkt = first_assigned_at ? 1 : 0
      sql = %(INSERT INTO #{stats_table} (#{REPORT_STATS.join(",")}) VALUES(#{account_id},#{ticket_id},
            '#{created_at.strftime('%Y-%m-%d 00:00:00')}','#{created_hour}',
            #{resolved_hour},1,#{resolved_tkt},0,#{assign_tkt},0,#{fcr_tkt},#{sla_tkt}))
      Sharding.run_on_master do 
        connection.execute(sql)
      end
    rescue Exception => e
      Rails.logger.error("Exception occurred while inserting data into stats table ::: #{e.message}")
      NewRelic::Agent.notice_error(e)
    end
  end

  def update_ticket_stats
    return unless (@ticket_state_changes.keys & STATS_ATTRIBUTES).any?
    begin
      stats_table_name = stats_table
      datetime = updated_at.strftime('%Y-%m-%d 00:00:00')
      select_sql = %(SELECT * FROM #{stats_table_name} where ticket_id = #{ticket_id} and 
        account_id = #{account_id} and created_at = '#{datetime}' )

      Sharding.run_on_master do 
        result = connection.execute(select_sql)
        f_hash = result.fetch_hash
        f_hash.symbolize_keys! unless f_hash.nil?
        check_and_update_ticket_stats(stats_table_name,f_hash,datetime)
      end
    rescue Exception => e
      Rails.logger.error("Exception occurred while updating data into stats table ::: #{e.message}")
      NewRelic::Agent.notice_error(e)
    end
  end

  def override_exchange_model(_action)
    changes = @ticket_state_changes.slice(*PRESENTER_FIELDS_MAPPING.keys)
    changes.keys.each do |key|
      changes[PRESENTER_FIELDS_MAPPING[key.to_sym]] = changes.delete key if PRESENTER_FIELDS_MAPPING[key.to_sym]
    end
    tickets.model_changes = changes if changes.present?
  end

private
  TICKET_LIST_VIEW_STATES = { :created_at => "created_at", :closed_at => "closed_at", 
    :resolved_at => "resolved_at", :agent_responded_at => "agent_responded_at", 
    :requester_responded_at => "requester_responded_at" }


  def resolved_at_dirty_fix
    return nil if tickets.blank? || tickets.active?
    Sharding.run_on_master { self.update_attribute(:resolved_at , updated_at) }
    NewRelic::Agent.notice_error(Exception.new("resolved_at is nil. Ticket state id is #{id}"))
    resolved_at
  end

  def closed_at_dirty_fix
    return nil unless tickets.present? && tickets.closed?
    Sharding.run_on_master { self.update_attribute(:closed_at, updated_at) }
    NewRelic::Agent.notice_error(Exception.new("closed_at is nil. Ticket state id is #{id}"))
    closed_at
  end

  def pending_since_dirty_fix
    return nil unless tickets.present? && tickets.pending?
    Sharding.run_on_master do
      self.update_attribute(:pending_since, updated_at)
    end
    NewRelic::Agent.notice_error(Exception.new("pending_since is nil. Ticket state id is #{id}"))
    pending_since
  end
  def update_ticket_state_changes
    @ticket_state_changes = self.changes.clone
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
    !("false".eql?(get_reports_redis_key ENTERPRISE_REPORTS_ENABLED))
  end

  def log_on_state_time(from_time, to_time, sla_policy, sla_detail, updated_time, obj)
    Rails.logger.debug "SLA :::: Account id #{obj.account_id} :: #{obj.id} #{obj.class} :: Inputs for updating on state time :: from_time :: #{from_time} to_time :: #{to_time} sla_policy :: #{sla_policy.id} - #{sla_policy.name} sla_detail :: #{sla_detail.id} - #{sla_detail.name} override_bhrs :: #{sla_detail.override_bhrs}"
    Rails.logger.debug "SLA :::: Account id #{obj.account_id} :: #{obj.id} #{obj.class} :: Updating on state time :: on_state_time_was :: #{obj.on_state_time.to_i} updated_time :: #{updated_time} on_state_time :: #{obj.on_state_time.to_i + updated_time}"
  end
end
