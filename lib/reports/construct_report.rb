module Reports::ConstructReport
  
  def build_tkts_hash(val,params)
    @val = val
    date_condition(params)
    @global_hash = tkts_by_status(fetch_tkts_by_status)
    merge_hash(:tkt_res_on_time,fetch_tkt_res_on_time)
    merge_hash(:over_due_tkts,fetch_overdue_tkts)
    merge_hash(:average_first_response_time,fetch_afrt)
    merge_for_fcr(:fcr,fetch_fcr)
    @global_hash
  end
  
  def merge_for_fcr(key,res_hash)
   res_hash.each do |tkt|
     responder = tkt.send("#{@val}_id").blank? ? "Unassigned" : tkt.send("#{@val}_id")
     status_hash = @global_hash.fetch(responder)
     status_hash.store(key,tkt.count)
     tot_tkts = status_hash.fetch(:tot_tkts)
     fcr_per = (tkt.count.to_f/tot_tkts.to_f) * 100
     status_hash.store(key,tkt.count)
     status_hash.store(:fcr_per,sprintf( "%0.02f", fcr_per))
     @global_hash.store(responder,status_hash)
  end
 end
  
  def tkts_by_status(tkts)
   data = {}
   tkts.each do |tkt|
    status_hash = {}
    #info_val = info.eql?("responder") ? "email" : "name"
    responder = tkt.send("#{@val}_id").blank? ? "Unassigned" : tkt.send("#{@val}_id")
    if data.has_key?(responder)
      status_hash = data.fetch(responder)
    end
    status_hash.store(TicketConstants::STATUS_NAMES_BY_KEY[tkt.status],tkt.count)
    tot_count = status_hash.fetch(:tot_tkts,0) + tkt.count.to_i
    status_hash.store(:tot_tkts,tot_count)
    data.store(responder,status_hash)
   end
     data
 end
 
 def merge_hash(key,res_hash)
   res_hash.each do |tkt|
     responder = tkt.send("#{@val}_id").blank? ? "Unassigned" : tkt.send("#{@val}_id")
     status_hash = @global_hash.fetch(responder)
     status_hash.store(key,tkt.count)
     @global_hash.store(responder,status_hash)
  end
 end
 
 def date_condition(params)
   @date_condition ||= begin 
    date_con = " helpdesk_ticket_states.resolved_at between '#{1.month.ago.to_s(:db)}' and now() "
    unless params[:start_date].blank? and params[:end_date].blank?
      date_con = " helpdesk_ticket_states.resolved_at > '#{Time.parse(params[:start_date]).beginning_of_day.to_s(:db)}' and helpdesk_ticket_states.resolved_at < '#{Time.parse(params[:end_date]).end_of_day.to_s(:db)}' "
    end
    date_con
   end
 end
 
 def fetch_tkts_by_type
   tkt_scoper.find( 
     :all,
     :include => @val, 
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :select => "count(*) count, ticket_type", 
     :conditions => @date_condition,
     :group => "ticket_type")
 end
 
 def fetch_tkts_by_status
   tkt_scoper.find( 
     :all,
     :include => @val, 
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :select => "count(*) count, #{@val}_id,status", 
     :conditions => @date_condition,
     :group => "#{@val}_id,status")
 end
 
 def fetch_tkt_res_on_time
   tkt_scoper.find(
     :all, 
     :select => "count(*) count, #{@val}_id", 
     :include => @val,
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :conditions => ["helpdesk_tickets.status IN (?,?) and helpdesk_tickets.due_by >=  helpdesk_ticket_states.resolved_at and (#{@date_condition})",TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved],TicketConstants::STATUS_KEYS_BY_TOKEN[:closed]],
     :group => "#{@val}_id")
 end
 
  
 def fetch_overdue_tkts
   tkt_scoper.find(
     :all, 
     :select => "count(*) count, #{@val}_id", 
     :include => @val,
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :conditions => " (helpdesk_tickets.due_by <  helpdesk_ticket_states.resolved_at ) and (#{@date_condition}) ",
     :group => "#{@val}_id")
 end
 
 def fetch_fcr
   tkt_scoper.find(
     :all, 
     :select => "count(*) count, #{@val}_id", 
     :include => @val,
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :conditions => " (helpdesk_ticket_states.resolved_at is not null)  and  helpdesk_ticket_states.inbound_count = 1 and (#{@date_condition}) ",
     :group => "#{@val}_id")
 end
 
 # Average First Response Time
 # (Time between Ticket Creation and the First Reponse)
 def fetch_afrt
   tkt_scoper.find(
     :all, 
     :select => "avg(helpdesk_ticket_states.first_response_time - helpdesk_tickets.created_at) count, #{@val}_id", 
     :include => @val,
     :joins => "INNER JOIN helpdesk_ticket_states on helpdesk_tickets.id = helpdesk_ticket_states.ticket_id", 
     :conditions => " (helpdesk_ticket_states.resolved_at is not null) and (#{@date_condition}) ",
     :group => "#{@val}_id")
 end
 
 def tkt_scoper
   scoper.tickets.visible
 end
 
 def scoper
   Account.current
 end

 def filter_options
  defs = []
      i = 0
      #default fields
      
      REPORT_DEFAULT_COLUMNS_ORDER.each do |name|
        cont = TicketConstants::DEFAULT_COLUMNS_KEYS_BY_TOKEN[name]
        defs.insert(i,{ get_op_list(cont).to_sym => cont , :placeholder => I18n.t("reports.custom_reports.placeholders.#{name.to_s.gsub('.','_')}") , :label => name, 
        :options => get_default_choices(name), :value => "" })
        i = i + 1
      end
      #Custom fields
      Account.current.ticket_fields.custom_dropdown_fields(:include => {:flexifield_def_entry => {:include => :flexifield_picklist_vals } } ).each do |col|
        defs.insert(i,{get_op_from_field(col).to_sym => get_container_from_field(col), :label => col.label, :name => col.name , :options => get_custom_choices(col), :value => "",:placeholder => ' ' })
        i = i + 1
      end
  defs
 end

  def get_id_from_field(tf)
    "flexifields.#{tf.flexifield_def_entry.flexifield_name}"
  end
  
  def get_container_from_field(tf)
    tf.field_type.gsub('custom_', '')
  end
  
  def get_op_from_field(tf)
    get_op_list(get_container_from_field(tf))    
  end
  
  def get_op_list(name)
    containers = Wf::Config.data_types[:helpdesk_tickets][name]
    container_klass = Wf::Config.containers[containers.first].constantize
    container_klass.operators.first   
  end
  
  def get_custom_choices(tf)
    choice_array = tf.choices
  end
  
  def get_default_choices(criteria_key)
    if criteria_key == :status
      return TicketConstants::STATUS_NAMES_BY_KEY.sort
    end
    
    if criteria_key == :ticket_type
      return Account.current.ticket_type_values.collect { |tt| [tt.value, tt.value] }
    end
    
    if criteria_key == :source
      return TicketConstants::SOURCE_NAMES_BY_KEY.sort
    end
    
    if criteria_key == :priority
      return TicketConstants::PRIORITY_NAMES_BY_KEY.sort
    end
    
    if criteria_key == :responder_id
      agents = []
      agents.concat(Account.current.users.technicians.collect { |au| [au.id, au.name] })
      return agents
    end
    
    if criteria_key == :group_id
      groups = []
      groups.concat(Account.current.groups.find(:all, :order=>'name' ).collect { |g| [g.id, g.name]})
      return groups
    end
    
    if criteria_key == :due_by
       return TicketConstants::DUE_BY_TYPES_NAMES_BY_KEY
    end
    
     if criteria_key == "helpdesk_tags.name"
       return Account.current.tags.collect { |au| [au.name, au.name] }
    end
      
   if criteria_key == "users.customer_id"
       return Account.current.customers.collect { |au| [au.id, au.name] }
    end
    
  return []
end

REPORT_DEFAULT_COLUMNS_ORDER = [:responder_id,:group_id,:priority,:ticket_type,:source,"helpdesk_tags.name","users.customer_id"]
 
end