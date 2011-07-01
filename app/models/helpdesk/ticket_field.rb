class Helpdesk::TicketField < ActiveRecord::Base
  
  set_table_name "helpdesk_ticket_fields"
  attr_protected  :account_id
  
  belongs_to :account
  belongs_to :flexifield_def_entry, :dependent => :destroy
  has_many :picklist_values, :as => :pickable, :class_name => 'Helpdesk::PicklistValue',
    :dependent => :destroy
  
  acts_as_list
   
  # scope_condition for acts_as_list
  def scope_condition
    "account_id = #{account_id}"
  end
  
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id
  
  before_create :populate_label
  named_scope :custom_fields, :conditions => ["flexifield_def_entry_id is not null"]
  named_scope :customer_visible, :conditions => { :visible_in_portal => true }  
  named_scope :customer_editable, :conditions => { :editable_in_portal => true }
  
  # Enumerator constant for mapping the CSS class name to the field type
  FIELD_CLASS = { :default_subject      => { :type => :default, :dom_type => "text",
                                              :form_field => "subject", :visible_in_view_form => false },
                  :default_requester    => { :type => :default, :dom_type => "requester",
                                              :form_field => "email"  , :visible_in_view_form => false },
                  :default_ticket_type  => { :type => :default, :dom_type => "dropdown"},
                  :default_status       => { :type => :default, :dom_type => "dropdown"}, 
                  :default_priority     => { :type => :default, :dom_type => "dropdown"},
                  :default_group        => { :type => :default, :dom_type => "dropdown_blank", :form_field => "group_id"},
                  :default_agent        => { :type => :default, :dom_type => "dropdown_blank", :form_field => "responder_id"},
                  :default_source       => { :type => :default, :dom_type => "hidden"},
                  :default_description  => { :type => :default, :dom_type => "paragraph", :visible_in_view_form => false },
                  :default_product      => { :type => :default, :dom_type => "dropdown_blank",
                                             :form_field => "email_config_id" },
                  :custom_text          => { :type => :custom, :dom_type => "text"},
                  :custom_paragraph     => { :type => :custom, :dom_type => "paragraph"},
                  :custom_checkbox      => { :type => :custom, :dom_type => "checkbox"},
                  :custom_number        => { :type => :custom, :dom_type => "number"},
                  :custom_dropdown      => { :type => :custom, :dom_type => "dropdown"}
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
         Helpdesk::Ticket::TYPE_OPTIONS
       when "default_agent" then
         account.users.technicians.collect { |c| [c.name, c.id] }
       when "default_group" then
         account.groups.collect { |c| [c.name, c.id] }
       when "default_product" then
         account.products.collect { |e| [e.name, e.id] }
       else
         []
    end
  end  
  
  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]
    super(:builder => xml, :skip_instruct => true) do |xml|
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
    c_attr.each { |c| picklist_values.build({:value => c[0]}) }
  end
  
  protected
    def populate_label
      self.label = name.titleize if label.blank?
      self.label_in_portal = label if label_in_portal.blank?
    end
end
