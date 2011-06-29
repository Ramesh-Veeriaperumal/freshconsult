class Helpdesk::TicketField < ActiveRecord::Base
  
  set_table_name "helpdesk_ticket_fields"
  attr_protected  :account_id
  
  belongs_to :account
  belongs_to :flexifield_def_entry, :dependent => :destroy
  has_many :picklist_values, :as => :pickable, :class_name => 'Helpdesk::PicklistValue',
    :dependent => :destroy
  
  acts_as_list
  
  # Enumerator constant for mapping the CSS class name to the field type
  FIELD_CLASS = { :default_subject      => "text",
                  :default_requester    => "text",
                  :default_ticket_type  => "dropdown",
                  :default_status       => "dropdown", 
                  :default_priority     => "dropdown",
                  :default_group        => "dropdown",
                  :default_agent        => "dropdown",
                  :default_source       => "dropdown",
                  :default_description  => "paragraph",
                  :custom_text          => "text",
                  :custom_paragraph     => "paragraph",
                  :custom_checkbox      => "checkbox",
                  :custom_number        => "number",
                  :custom_dropdown      => "dropdown"
                }
  
  # scope_condition for acts_as_list
  def scope_condition
    "account_id = #{account_id}"
  end
  
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id
  
  before_create :populate_label
  named_scope :custom_fields, :conditions => ["flexifield_def_entry_id is not null"]
  
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
