class Helpdesk::NestedTicketField < ActiveRecord::Base
  self.primary_key = :id

  # add for multiform phase 1 migration
  include Helpdesk::Ticketfields::TicketFormFields

  self.table_name =  "helpdesk_nested_ticket_fields"
  attr_protected  :account_id

  belongs_to_account
  belongs_to :ticket_field
  belongs_to :flexifield_def_entry, :dependent => :destroy


  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id
    
  before_create :populate_label

  #https://github.com/rails/rails/issues/988#issuecomment-31621550
  # Phase1:- multiform , will be removed once migration is done.
  after_commit ->(obj) { obj.save_form_field_mapping }, on: :create
  after_commit ->(obj) { obj.save_form_field_mapping }, on: :update
  after_commit :remove_form_field_mapping, on: :destroy
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

  def api_name
    #(-Account.current.id_length-2) will omit "_accountId" from name
    is_default_field? ? name : (TicketConstants::TICKET_FIELD_INVALID_START_CHAR.index(label[0]) ? name[3..(-Account.current.id_length-2)] : name[0..(-Account.current.id_length-2)])
  end

  protected

    def save_form_field_mapping
      save_form_nested_field(self)
    end

    def remove_form_field_mapping
      remove_form_nested_field(self)
    end
end