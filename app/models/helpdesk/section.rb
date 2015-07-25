class Helpdesk::Section < ActiveRecord::Base

  self.primary_key = :id
  self.table_name = "helpdesk_sections"

  serialize :options

  attr_protected :account_id
  
  belongs_to_account
  has_many :section_fields, :dependent => :destroy, :order => 'position'
  has_many :section_picklist_mappings, :class_name => 'Helpdesk::SectionPicklistValueMapping', 
                                       :dependent => :destroy
  validates_presence_of :label
  validates_uniqueness_of :label, :scope => :account_id, :case_sensitive => false

  accepts_nested_attributes_for :section_picklist_mappings, :allow_destroy => true
  accepts_nested_attributes_for :section_fields, :allow_destroy => true

  def parent_ticket_field_id
    section_picklist_mappings[0].picklist_value.pickable_id
  end
end
