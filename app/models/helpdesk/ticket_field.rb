class Helpdesk::TicketField < ActiveRecord::Base
  
  set_table_name "helpdesk_ticket_fields"
  attr_protected  :account_id
  
  belongs_to :account
  belongs_to :flexifield_def_entry, :dependent => :destroy
  has_many :picklist_values, :as => :pickable, :class_name => 'Helpdesk::PicklistValue',
    :dependent => :destroy
  has_many :nested_ticket_fields, :class_name => 'Helpdesk::NestedTicketField', :dependent => :destroy, :order => "level"
    
  before_destroy :delete_from_ticket_filter
  before_update :delete_from_ticket_filter
  before_save :set_portal_edit
  
  acts_as_list
  
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
  named_scope :nested_fields, :conditions => ["flexifield_def_entry_id is not null and field_type = 'nested_field'"]

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
                  :default_description  => { :type => :default, :dom_type => "html_paragraph", :visible_in_view_form => false, :form_field => "description_html" },
                  :default_product      => { :type => :default, :dom_type => "dropdown",
                                             :form_field => "email_config_id" },
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
                                              :va_handler => "dropdown"}
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

  def choices
     case field_type
       when "custom_dropdown" then
         picklist_values.collect { |c| [c.value, c.value] }
       when "default_priority" then
         Helpdesk::Ticket::PRIORITY_OPTIONS
       when "default_source" then
         Helpdesk::Ticket::SOURCE_OPTIONS
       when "default_status" then
         Helpdesk::Ticket::STATUS_OPTIONS
       when "default_ticket_type" then
         picklist_values.collect { |c| [c.value, c.value] }
       when "default_agent" then
         account.agents(:include => :user).collect { |c| [c.user.name, c.user.id] }
       when "default_group" then
         account.groups.collect { |c| [c.name, c.id] }
       when "default_product" then
         account.products.collect { |e| [e.name, e.id] }.insert(0, ['...', account.primary_email_config.id])
       when "nested_field" then
         picklist_values.collect { |c| [c.value, "#{c.id}"] }
       else
         []
    end
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
      xml.choices do
        self.choices.each do |k,v|  
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
  
  def choices=(c_attr)
    picklist_values.clear
    c_attr.each do |c| 
      if c.size > 2 && c[2].is_a?(Array)
        picklist_values.build({:value => c[0], :choices => c[2]})
      else
        picklist_values.build({:value => c[0]})
      end
    end  
  end
  
  protected
    def populate_label
      self.label = name.titleize if label.blank?
      self.label_in_portal = label if label_in_portal.blank?
   end
   def set_portal_edit
      self.editable_in_portal = false unless visible_in_portal
      self
   end
  
  
end
