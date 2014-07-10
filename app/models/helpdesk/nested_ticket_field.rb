class Helpdesk::NestedTicketField < ActiveRecord::Base

  # add for multiform phase 1 migration
  include Helpdesk::Ticketfields::TicketFormFields

  set_table_name "helpdesk_nested_ticket_fields"
  attr_protected  :account_id

  belongs_to_account
  belongs_to :ticket_field
  belongs_to :flexifield_def_entry, :dependent => :destroy


  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id
    
  before_create :populate_label

  # Phase1:- multiform , will be removed once migration is done.
  after_commit_on_create :save_form_field_mapping
  after_commit_on_update :save_form_field_mapping
  after_commit_on_destroy :remove_form_field_mapping
  #Phase1:- end

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

  protected

    def save_form_field_mapping
      save_form_nested_field(self)
    end

    def remove_form_field_mapping
      remove_form_nested_field(self)
    end
end