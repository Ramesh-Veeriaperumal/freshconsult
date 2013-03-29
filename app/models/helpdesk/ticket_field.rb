class Helpdesk::TicketField < ActiveRecord::Base
  
  serialize :field_options

  include Helpdesk::Ticketfields::TicketStatus
  include Cache::Memcache::Helpdesk::TicketField
  
  set_table_name "helpdesk_ticket_fields"
  attr_protected  :account_id
  
  belongs_to :account
  belongs_to :flexifield_def_entry, :dependent => :destroy
  has_many :picklist_values, :as => :pickable, :class_name => 'Helpdesk::PicklistValue',:include => :sub_picklist_values,
    :dependent => :destroy, :order => "position"
  has_many :nested_ticket_fields, :class_name => 'Helpdesk::NestedTicketField', :dependent => :destroy, :order => "level"
    
  has_many :ticket_statuses, :class_name => 'Helpdesk::TicketStatus', :autosave => true, :dependent => :destroy, :order => "position"
  
  before_validation :populate_choices

  before_destroy :delete_from_ticket_filter
  before_update :delete_from_ticket_filter
  before_save :set_portal_edit
  xss_terminate
  acts_as_list

  after_commit :clear_cache
  
  def delete_from_ticket_filter
    if is_dropdown_field?
      Account.current.ticket_filters.each do |filter|
        con_arr = filter.data[:data_hash]
        unless  con_arr.blank?
          con_arr.each do |condition|
            con_arr.delete(condition) if condition["condition"].eql?("flexifields.#{flexifield_def_entry.flexifield_name}")
          end
          filter.query_hash = con_arr
          filter.save
        end
      end
    end
  end
  
  def is_dropdown_field?
    field_type.include?("dropdown")
  end
   
  # scope_condition for acts_as_list
  def scope_condition
    "account_id = #{account_id}"
  end
  
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id
  
  before_create :populate_label
  
  
  named_scope :custom_fields, :conditions => ["flexifield_def_entry_id is not null"]
  named_scope :custom_dropdown_fields, :conditions => ["flexifield_def_entry_id is not null and field_type = 'custom_dropdown'"]
  named_scope :customer_visible, :conditions => { :visible_in_portal => true }
  named_scope :customer_editable, :conditions => { :editable_in_portal => true }
  named_scope :type_field, :conditions => { :name => "ticket_type" }
  named_scope :status_field, :conditions => { :name => "status" }
  named_scope :nested_fields, :conditions => ["flexifield_def_entry_id is not null and field_type = 'nested_field'"]
  named_scope :nested_and_dropdown_fields, :conditions=>["flexifield_def_entry_id is not null and (field_type = 'nested_field' or field_type='custom_dropdown')"]

  # Enumerator constant for mapping the CSS class name to the field type
  FIELD_CLASS = { :default_subject      => { :type => :default, :dom_type => "text",
                                              :form_field => "subject", :visible_in_view_form => false },
                  :default_requester    => { :type => :default, :dom_type => "requester",
                                              :form_field => "email"  , :visible_in_view_form => false },
                  :default_ticket_type  => { :type => :default, :dom_type => "dropdown" },
                  :default_status       => { :type => :default, :dom_type => "dropdown"}, 
                  :default_priority     => { :type => :default, :dom_type => "dropdown"},
                  :default_group        => { :type => :default, :dom_type => "dropdown_blank", :form_field => "group_id"},
                  :default_agent        => { :type => :default, :dom_type => "dropdown_blank", :form_field => "responder_id"},
                  :default_source       => { :type => :default, :dom_type => "hidden"},
                  :default_description  => { :type => :default, :dom_type => "html_paragraph", 
                                              :form_field => "description_html", :visible_in_view_form => false },
                  :default_product      => { :type => :default, :dom_type => "dropdown_blank",
                                             :form_field => "product_id" },
                  :custom_text          => { :type => :custom, :dom_type => "text", 
                                             :va_handler => "text" },
                  :custom_paragraph     => { :type => :custom, :dom_type => "paragraph", 
                                             :va_handler => "text" },
                  :custom_checkbox      => { :type => :custom, :dom_type => "checkbox", 
                                             :va_handler => "checkbox" },
                  :custom_number        => { :type => :custom, :dom_type => "number", 
                                             :va_handler => "numeric"},
                  :custom_dropdown      => { :type => :custom, :dom_type => "dropdown", 
                                             :va_handler => "dropdown"},
                  :nested_field         => {:type => :custom, :dom_type => "dropdown_blank",
                                              :va_handler => "nested_field"}
                }

  def dom_type
    FIELD_CLASS[field_type.to_sym][:dom_type]
  end

  def field_name
    FIELD_CLASS[field_type.to_sym][:form_field] || name
  end
  
  def visible_in_view_form?
    view = FIELD_CLASS[field_type.to_sym][:visible_in_view_form]
    ( view.nil? || view )
  end
  
  def is_default_field?
    (FIELD_CLASS[field_type.to_sym][:type] === :default)
  end

  def choices(ticket = nil)
     case field_type
       when "custom_dropdown" then
         picklist_values.collect { |c| [c.value, c.value] }
       when "default_priority" then
         TicketConstants.priority_names
       when "default_source" then
         TicketConstants.source_names
       when "default_status" then
         Helpdesk::TicketStatus.statuses_from_cache(account)
       when "default_ticket_type" then
         account.ticket_types_from_cache.collect { |c| [c.value, c.value] }
       when "default_agent" then
        return group_agents(ticket)
       when "default_group" then
         account.groups_from_cache.collect { |c| [c.name, c.id] }
       when "default_product" then
         account.products.collect { |e| [e.name, e.id] }
       when "nested_field" then
         picklist_values.collect { |c| [c.value, c.value] }
       else
         []
     end
  end  
  
  def nested_choices
    self.picklist_values.collect { |c| 
      [c.value, c.value, c.sub_picklist_values.collect { |sub_c|
            [sub_c.value, sub_c.value, sub_c.sub_picklist_values.collect { |i_c| [i_c.value,i_c.value] } ] }
      ]
    }
  end

  def all_status_choices(disp_col_name=nil)
    disp_col_name = disp_col_name.nil? ? "customer_display_name" : "name"
    self.ticket_statuses.collect{|st| [Helpdesk::TicketStatus.translate_status_name(st, disp_col_name), st.status_id]}
  end

  def visible_status_choices(disp_col_name=nil)
    disp_col_name = disp_col_name.nil? ? "customer_display_name" : "name"
    self.ticket_statuses.visible.collect{|st| [Helpdesk::TicketStatus.translate_status_name(st, disp_col_name), st.status_id]}
  end

  def nested_levels
    nested_ticket_fields.map{ |l| { :id => l.id, :label => l.label, :label_in_portal => l.label_in_portal, 
      :name => l.name, :level => l.level, :field_type => "nested_child" } } if field_type == "nested_field"
  end

  def levels
    nested_ticket_fields.map{ |l| { :id => l.id, :label => l.label, :label_in_portal => l.label_in_portal, 
      :description => l.description, :level => l.level, :position => 1, :field_type => "nested_child", 
      :type => "dropdown" } } if field_type == "nested_field"
  end

  def level_three_present
    (nested_ticket_fields.last.level == 3) if field_type == "nested_field"
  end

  def dropdown_selected(dropdown_values, selected_value)  
      selected_text = ""
      dropdown_values.each do |i|
        if (i[1] == selected_value)
           selected_text = i[0] 
           break
        end  
      end
      selected_text
  end
  
  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]
    super(:builder => xml, :skip_instruct => true,:except => [:account_id,:import_id]) do |xml|
      if field_type == "nested_field"
        xml.nested_ticket_fields do
          nested_ticket_fields.each do |nested_ticket_field|
            xml.nested_ticket_field do
              xml.tag!("id",nested_ticket_field.id)
              xml.tag!("name",nested_ticket_field.name)
              xml.tag!("label",nested_ticket_field.label)
              xml.tag!("label_in_portal",nested_ticket_field.label_in_portal)
              xml.tag!("level",nested_ticket_field.level)
            end
          end
        end
        xml.choices do
          picklist_values.each do |picklist_value|
            xml.option do
              xml.tag!("id",picklist_value.id)
              xml.tag!("value",picklist_value.value)
              to_xml_nested_fields(xml, picklist_value)
            end
          end
        end
      else
        xml.choices do
          choices.each do |k,v|  
            if v != "0"
              xml.option do
                xml.tag!("id",k)
                xml.tag!("value",v)
              end
            end
          end
        end
      end
    end
  end
  
  def to_xml_nested_fields(xml, picklist_value)
    return if picklist_value.sub_picklist_values.empty?
    
    xml.choices do
      picklist_value.sub_picklist_values.each do |sub_picklist_value|
        xml.option do
          xml.tag!("id",sub_picklist_value.id)
          xml.tag!("value",sub_picklist_value.value)
          to_xml_nested_fields(xml, sub_picklist_value)
        end
      end
    end
  end

  def choices=(c_attr)
    @choices = c_attr
  end

  def company_cc_in_portal?
    field_options.fetch("portalcc") && field_options.fetch("portalcc_to").eql?("company")
  end

  def all_cc_in_portal?
    field_options.fetch("portalcc") && field_options.fetch("portalcc_to").eql?("all")
  end

  def portal_cc_field?
    field_options.fetch("portalcc")
  end
  
  protected

    def group_agents(ticket)
      if ticket && ticket.group_id
        agent_list = account.agent_groups.find(:all, 
                                               :joins =>"inner join users on 
                                                          agent_groups.account_id = 
                                                                    users.account_id and 
                                                          users.id = agent_groups.user_id",
                                               :conditions => { :group_id => ticket.group_id, 
                                                                :users => {:deleted => false}
                                                              }
                                              ).collect{ |c| [c.user.name, c.user.id]}

        if !ticket.responder_id || agent_list.any? { |a| a[1] == ticket.responder_id }
          return agent_list
        end

        responder = account.agents_from_cache.detect { |a| a.user.id == ticket.responder_id }
        agent_list += [[ responder.user.name, ticket.responder_id ]] if responder
        return agent_list
      end
      
      account.agents_from_cache.collect { |c| [c.user.name, c.user.id] }
    end

    def populate_choices
      return unless @choices
      if(["nested_field","custom_dropdown","default_ticket_type"].include?(self.field_type))
        picklist_values.clear
        clear_picklist_cache
        @choices.each do |c| 
          if c.size > 2 && c[2].is_a?(Array)
            picklist_values.build({:value => c[0], :choices => c[2]})
          else
            picklist_values.build({:value => c[0]})
          end
        end
      elsif("default_status".eql?(self.field_type))
        @choices.each_with_index{|attr,position| update_ticket_status(attr,position)}
      end
    end    

    def populate_label
      self.label = name.titleize if label.blank?
      self.label_in_portal = label if label_in_portal.blank?
   end
   def set_portal_edit
      self.editable_in_portal = false unless visible_in_portal
      self
   end

end
