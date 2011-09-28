class Helpdesk::Filters::CustomTicketFilter < Wf::Filter
  
  include Search::TicketSearch
  
  attr_accessor :query_hash 
  
  MODEL_NAME = "Helpdesk::Ticket"
  
  def self.deleted_condition(input)
    { "condition" => "deleted", "operator" => "is", "value" => input}
  end
  
  def self.spam_condition(input)
    { "condition" => "spam", "operator" => "is", "value" => input}
  end

  DEFAULT_FILTERS ={ 
                      "spam" => [spam_condition(true),deleted_condition(false)],
                      "deleted" =>  [spam_condition(false),deleted_condition(true)],
                      "overdue" =>  [{ "condition" => "due_by", "operator" => "due_by_op", "value" => TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:all_due]},spam_condition(false),deleted_condition(false) ],
                      "on_hold" => [{ "condition" => "status", "operator" => "is_in", "value" => TicketConstants::STATUS_KEYS_BY_TOKEN[:pending]},spam_condition(false),deleted_condition(false)],
                      "open" => [{ "condition" => "status", "operator" => "is_in", "value" => TicketConstants::STATUS_KEYS_BY_TOKEN[:open]},spam_condition(false),deleted_condition(false)],
                      "due_today" => [{ "condition" => "due_by", "operator" => "due_by_op", "value" => TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_today]},spam_condition(false),deleted_condition(false)],
                      "new" => [{ "condition" => "responder_id", "operator" => "is_in", "value" => ""},spam_condition(false),deleted_condition(false)],
                      "monitored_by" => [{ "condition" => "helpdesk_subscriptions.user_id", "operator" => "is_in", "value" => "0"},spam_condition(false),deleted_condition(false)],
                      "new_my_open" => [{ "condition" => "status", "operator" => "is_in", "value" => TicketConstants::STATUS_KEYS_BY_TOKEN[:open]},{ "condition" => "responder_id", "operator" => "is_in", "value" => "-1,0"},spam_condition(false),deleted_condition(false)],
                      "all_tickets" => [spam_condition(false),deleted_condition(false)]
                   }
                   
                   
  after_create :create_accesible
  after_update :save_accessible
   
  def create_accesible     
    self.accessible = Admin::UserAccess.new( {:account_id => account_id }.merge(self.visibility)  )
    self.save
  end
  
  def save_accessible
    self.accessible.update_attributes(self.visibility)    
  end
  
  def self.my_ticket_filters(user)
    self.find(:all, :joins =>"JOIN admin_user_accesses acc ON acc.accessible_id = wf_filters.id AND acc.accessible_type = 'Wf::Filter' LEFT JOIN agent_groups ON acc.group_id=agent_groups.group_id", :order => 'created_at desc', :conditions =>["acc.VISIBILITY=#{Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]} OR agent_groups.user_id=#{user.id} OR (acc.VISIBILITY=#{Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]} and acc.user_id=#{user.id})"])
  end
  
  def self.edit_ticket_filters(user)
    self.find( :all, 
               :joins =>"JOIN admin_user_accesses acc ON acc.accessible_id = wf_filters.id AND acc.accessible_type = 'Wf::Filter'  LEFT JOIN agent_groups ON acc.group_id=agent_groups.group_id" +
                        " INNER JOIN users ON (acc.user_id = users.id and users.id = #{user.id}) OR (acc.VISIBILITY=#{Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]} AND users.id = #{user.id} AND users.user_role in (#{User::USER_ROLES_KEYS_BY_TOKEN[:admin]},#{User::USER_ROLES_KEYS_BY_TOKEN[:account_admin]}))" +
                        " OR (acc.VISIBILITY = #{Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents]} and agent_groups.user_id = users.id and users.id = #{user.id}) OR (acc.VISIBILITY=#{Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]} and acc.user_id = #{user.id})")
  end
  
  def definition
     @definition ||= begin
      defs = {}
      #default fields
      TicketConstants::DEFAULT_COLUMNS_KEYS_BY_TOKEN.each do |name,cont|
        defs[name.to_sym] = { get_op_list(cont).to_sym => cont  , :name => name, :container => cont,     
        :operator => get_op_list(cont), :options => get_default_choices(name.to_sym) }
      end
      #Custome fields
      Account.current.ticket_fields.custom_dropdown_fields(:include => {:flexifield_def_entry => {:include => :flexifield_picklist_vals } } ).each do |col|
        defs[get_id_from_field(col).to_sym] = {get_op_from_field(col).to_sym => get_container_from_field(col) ,:name => col.label, :container => get_container_from_field(col), :operator => get_op_from_field(col), :options => get_custom_choices(col) }
      end 
      
      ##### Some hack for default values
      defs["helpdesk_subscriptions.user_id".to_sym] = ({:operator => :is_in,:is_in => :dropdown, :options => [], :name => "helpdesk_subscriptions.user_id", :container => :dropdown})
      defs[:spam] = ({:operator => :is,:is => :boolean, :options => [], :name => :spam, :container => :boolean})
      defs[:deleted] = ({:operator => :is,:is => :boolean, :options => [], :name => :deleted, :container => :boolean})
      
      defs
    end
  end
  
  def default_order
    'created_at'
  end
  
  def default_filter(filter_name)
     self.name = filter_name.blank? ? "new_my_open" : filter_name
     DEFAULT_FILTERS.fetch(filter_name, DEFAULT_FILTERS["new_my_open"])
  end
  
  def self.deserialize_from_params(params)
    filter = Account.current.ticket_filters.new(params[:wf_model])
    filter.deserialize_from_params(params)
  end
 
  
  def deserialize_from_params(params)  
    @conditions = []
    @match                = :and
    @key                  = params[:wf_key]         || self.id.to_s
    self.model_class_name = params[:wf_model]       if params[:wf_model]
    
    @per_page             = params[:wf_per_page]    || default_per_page
    @page                 = params[:page]           || 1
    @order_type           = params[:wf_order_type]  || default_order_type
    @order                = params[:wf_order]       || default_order
    
    self.id   =  params[:wf_id].to_i      unless params[:wf_id].blank?
    self.name =  params[:filter_name]     unless params[:filter_name].blank?
    
    @fields = []
    unless params[:wf_export_fields].blank?
      params[:wf_export_fields].split(",").each do |fld|
        @fields << fld.to_sym
      end
    end

    if params[:wf_export_format].blank?
      @format = :html
    else  
      @format = params[:wf_export_format].to_sym
    end
    
    action_hash = []
    if !params[:data_hash].blank? 
      action_hash = params[:data_hash]
      action_hash = ActiveSupport::JSON.decode params[:data_hash] if !params[:data_hash].kind_of?(Array)
    end
    if params[:filter_name].blank?
      action_hash.push({ "condition" => "spam", "operator" => "is", "value" => false})
      action_hash.push({ "condition" => "deleted", "operator" => "is", "value" => false})
    end
    action_hash = default_filter(params[:filter_name])  if params[:data_hash].blank?
    self.query_hash = action_hash
   
    action_hash.each do |filter|
      add_condition(filter["condition"], filter["operator"].to_sym, filter["value"]) unless filter["value"].nil?
    end

    if params[:wf_submitted] == 'true'
      validate!
    end
    
    return self
  end
  
  def sql_conditions
    @sql_conditions  ||= begin

      if errors? 
        all_sql_conditions = [" 1 = 2 "] 
      else
        all_sql_conditions = [""]
        condition_at(0)
        0.upto(size - 1) do |index|
          condition = condition_at(index)
          if condition.key.to_s.include?("responder_id") or condition.key.to_s.include?("helpdesk_subscriptions.user_id") 
            condition.container.values[0] = condition.container.value.gsub("0",User.current.id.to_s) 
          end
          
          if condition.key.to_s.include?("group_id")
            if condition.container.value.include?("0")
              group_ids = User.current.agent_groups.find(:all, :select => 'group_id').map(&:group_id)
              group_ids = ["-1"] if group_ids.empty?
              condition.container.values[0] = condition.container.value.gsub("0",group_ids.join(",")) 
            end
          end
          
          sql_condition = condition.container.sql_condition
          
          unless sql_condition
            raise Wf::FilterException.new("Unsupported operator  for container #{condition.container.class.name}")
          end
          
          if all_sql_conditions[0].size > 0
            all_sql_conditions[0] << ( match.to_sym == :any ? "  OR" : " AND ")
          end
          
          all_sql_conditions[0] << sql_condition[0]
          sql_condition[1..-1].each do |c|
            all_sql_conditions << c
          end
        end
      end
      
      all_sql_conditions
    end
  end
  
  def serialize_to_params(merge_params = {})
    params = {}
    params[:wf_type]        = self.class.name
    params[:wf_match]       = match
    params[:wf_model]       = model_class_name
    params[:wf_order]       = order
    params[:wf_order_type]  = order_type
    params[:wf_per_page]    = per_page
    
    
    params[:data_hash] = self.query_hash
    params
  
  end

  def results
    @results ||= begin
      handle_empty_filter! 
      all_conditions = sql_conditions
      all_joins = get_joins(sql_conditions)
      recs = model_class.paginate(:order => order_clause, :page => page, :per_page => per_page, :conditions => all_conditions, :joins => all_joins)
      recs.wf_filter = self
      recs
    end
  end
  
  def get_joins(all_conditions)
    all_joins = joins
    all_joins[0].concat(tag_joins) if all_conditions[0].include?("helpdesk_tags.name")
    all_joins[0].concat(monitor_ships_join) if all_conditions[0].include?("helpdesk_subscriptions.user_id")
    all_joins
  end
  
 def monitor_ships_join
   " INNER JOIN helpdesk_subscriptions ON helpdesk_subscriptions.ticket_id = helpdesk_tickets.id  "
 end

 def tag_joins
   " INNER JOIN helpdesk_tag_uses ON helpdesk_tag_uses.taggable_id = helpdesk_tickets.id INNER JOIN helpdesk_tags ON helpdesk_tag_uses.tag_id = helpdesk_tags.id  "
 end
  
  
  def joins
    ["INNER JOIN flexifields ON flexifields.flexifield_set_id = helpdesk_tickets.id  "]
  end      
  
end