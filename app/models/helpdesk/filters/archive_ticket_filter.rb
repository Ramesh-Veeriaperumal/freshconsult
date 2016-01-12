class Helpdesk::Filters::ArchiveTicketFilter < Wf::Filter
  include Search::TicketSearch

  MODEL_NAME = "Helpdesk::ArchiveTicket"
  attr_accessor :query_hash 

  def model_class
    Helpdesk::ArchiveTicket
  end

  def deserialize_from_params(params)
    @conditions = []
    @match                = params[:wf_match]       || :all
    @key                  = params[:wf_key]         || self.id.to_s
    self.model_class_name = params[:wf_model]       if params[:wf_model]
    
    @per_page             = params[:wf_per_page]    || default_per_page
    @page                 = params[:page]           || 1
    @order_type           = params[:wf_order_type] || default_order_type
    @order                = params[:wf_order] || default_order
    @without_pagination   = params[:without_pagination]         if params[:without_pagination]
    @filter_fields_to_select   = params[:select_fields]         if params[:select_fields]
    @html_format = params[:html_format] || false
    
    self.id   =  params[:wf_id].to_i  unless params[:wf_id].blank?
    self.name =  params[:wf_name]     unless params[:wf_name].blank?
    
    action_hash = []
    if !params[:data_hash].blank? 
      action_hash = params[:data_hash]
      action_hash = ActiveSupport::JSON.decode params[:data_hash] if !params[:data_hash].kind_of?(Array)
    end
    self.query_hash = action_hash

    action_hash.each do |filter|
      add_condition(filter["condition"], filter["operator"].to_sym, filter["value"]) unless filter["value"].nil?
    end

    add_requester_conditions(params)
    add_tag_filter(params)

    if params[:wf_submitted] == 'true'
      validate!
    end

    return self
  end

  def add_requester_conditions(params)
    add_condition("requester_id", :is_in, params[:requester_id]) unless params[:requester_id].blank?
    add_condition("owner_id", :is_in, params[:company_id]) unless params[:company_id].blank?
  end

  def add_tag_filter(params)
    add_condition("helpdesk_tags.id", :is_in, params[:tag_id]) unless params[:tag_id].blank?
  end

  def definition
     @definition ||= begin
      defs = {}
      #default fields
      TicketConstants::DEFAULT_COLUMNS_KEYS_BY_TOKEN.each do |name,cont|
        defs[name.to_sym] = { get_op_list(cont).to_sym => cont  , :name => name, :container => cont,     
        :operator => get_op_list(cont), :options => get_default_choices(name.to_sym) }
      end
      
      ##### Some hack for default values
      defs[:requester_id] = ({:operator => :is_in,:is_in => :dropdown, :options => [], :name => :requester_id, :container => :dropdown})  # Added for email based custom view, which will be used in integrations.
      defs[:"archive_tickets.id"] = ({:operator => :is_in,:is_in => :dropdown, :options => [], :name => "archive_tickets.id", :container => :dropdown})
      defs
    end
  end
  
  def default_order
    'created_at'
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
          handle_special_values(condition)

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

  def results
    Sharding.run_on_slave do
      @results ||= begin
        handle_empty_filter! 

        all_conditions = sql_conditions
        all_joins = get_joins(sql_conditions)

        if @without_pagination
          return model_class.find(:all , :select => @filter_fields_to_select , :order => order_clause, 
                                        :limit => per_page, :offset => (page - 1) * per_page,
                                        :conditions => all_conditions, :joins => all_joins)
        end
        
        select = @html_format ? ticket_select : "archive_tickets.*"
        select = "DISTINCT(archive_tickets.id) as 'unique_id' , #{select}" if all_conditions[0].include?("helpdesk_tags.name")

        recs = model_class.paginate(:select => select,
                                   :order => order_clause, :page => page, 
                                   :per_page => per_page, :conditions => all_conditions, :joins => all_joins,
                                   :total_entries => count_without_query).preload([:ticket_status, :responder, :requester])
        recs.wf_filter = self
        recs
      end
    end
  end

  def count_without_query
    # ActiveRecord::Base.connection.select_values('SELECT FOUND_ROWS() AS "TOTAL_ROWS"').pop
    per_page.to_f * page.to_f+1
  end

  def ticket_select
    " archive_tickets.id, archive_tickets.subject, archive_tickets.requester_id, archive_tickets.responder_id,
      archive_tickets.status, archive_tickets.priority, archive_tickets.display_id, archive_tickets.source, 
      archive_tickets.group_id, archive_tickets.ticket_type"
  end

  def get_joins(all_conditions)
    all_joins = [""]
    all_joins[0].concat(users_join) if all_conditions[0].include?("users.customer_id")
    all_joins[0].concat(tags_join) if all_conditions[0].include?("helpdesk_tags.name")
    all_joins[0].concat(statuses_join) if all_conditions[0].include?("helpdesk_ticket_statuses")
    all_joins
  end

  def users_join
    " INNER JOIN users ON users.id = archive_tickets.requester_id  and  users.account_id = archive_tickets.account_id  "
  end

  def tags_join
    " INNER JOIN `helpdesk_tag_uses` ON (`archive_tickets`.`id` = `helpdesk_tag_uses`.`taggable_id` 
                            AND `helpdesk_tag_uses`.`taggable_type` = 'Helpdesk::ArchiveTicket') 
          INNER JOIN `helpdesk_tags` ON (`helpdesk_tags`.`id` = `helpdesk_tag_uses`.`tag_id`)  "
  end
  
  def statuses_join
    "INNER JOIN helpdesk_ticket_statuses ON 
          archive_tickets.account_id = helpdesk_ticket_statuses.account_id AND 
            archive_tickets.status = helpdesk_ticket_statuses.status_id"
  end

  private

  def handle_special_values(condition)    
    key = condition.key.to_s
    type = case 
    when key.include?("responder_id")
      :user
    when key.include?("group_id")
      :group
    end

    if type
      values = condition.container.value.split(",")
      if values.include?("0")
        values.delete("0")
        values << convert_special_values(type)
      end
      condition.container.values[0] = values.join(",")
    end
  end

  def convert_special_values(type)
    case type
    when :user
      User.current.id.to_s
    when :group
      ids = User.current.agent_groups.pluck(:group_id)
      ids.blank? ? ["-2"] : ids
    end
  end

end
