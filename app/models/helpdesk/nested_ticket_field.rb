class Helpdesk::NestedTicketField < ActiveRecord::Base
  
  clear_memcache [TICKET_FIELDS_FULL, CUSTOMER_EDITABLE_TICKET_FIELDS_FULL, CUSTOMER_EDITABLE_TICKET_FIELDS_WITHOUT_PRODUCT]
    
  attr_accessible :label, :label_in_portal, :description, :level, :type, :name
  self.primary_key = :id

  self.table_name =  "helpdesk_nested_ticket_fields"
  attr_protected  :account_id

  concerned_with :presenter

  belongs_to_account
  belongs_to :ticket_field, :class_name => "Helpdesk::TicketField"
  belongs_to :flexifield_def_entry, :dependent => :destroy


  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id
    
  before_create :populate_label

  alias_attribute :i18n_label, :label

  def dom_type
  	"dropdown_blank"
  end

  def field_name
  	name
  end

  def is_default_field?
    false
  end

  def field_type
    "nested_child"
  end

  def dropdown_selected(dropdown_values, selected_value)
      selected_value = dropdown_values.select { |i| i[1] == selected_value }.first
      (selected_value && !selected_value[0].blank?) ?  selected_value[0] : ""
  end

  def populate_label
  	self.label = name.titleize if label.blank?
  	self.label_in_portal = label if label_in_portal.blank?
  end

  def translated_label_in_portal
    self.ticket_field.translated_label_in_portal(self)
  end

end
