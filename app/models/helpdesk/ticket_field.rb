class Helpdesk::TicketField < ActiveRecord::Base
  
  set_table_name "helpdesk_ticket_fields"
  attr_protected  :account_id
  
  belongs_to :account
  belongs_to :flexifield_def_entry
  
  acts_as_list
  
  # scope_condition for acts_as_list
  def scope_condition
    "account_id = #{account_id}"
  end
  
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :account_id
  
  before_create :populate_label
  named_scope :custom_fields, :conditions => ["flexifield_def_entry_id is not null"]
  
  protected
    def populate_label
      self.label = name.titleize if label.blank?
      self.label_in_portal = label if label_in_portal.blank?
    end
end
