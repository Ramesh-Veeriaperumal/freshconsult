class Helpdesk::Section < ActiveRecord::Base

  include Cache::Memcache::Helpdesk::Section

  clear_memcache [TICKET_FIELDS_FULL, CUSTOMER_EDITABLE_TICKET_FIELDS_FULL, CUSTOMER_EDITABLE_TICKET_FIELDS_WITHOUT_PRODUCT]

  self.primary_key = :id
  self.table_name = "helpdesk_sections"

  serialize :options, Hash

  attr_protected :account_id

  concerned_with :presenter
  
  belongs_to_account

  swindle :all_sections, attrs: %i[id label ticket_field_id]
  belongs_to :ticket_field, :class_name => "Helpdesk::TicketField"
  has_many :section_fields, :dependent => :destroy, :order => 'position'
  has_many :section_picklist_mappings, :class_name => 'Helpdesk::SectionPicklistValueMapping', 
                                       :dependent => :destroy
  has_many :required_ticket_fields, :class_name => 'Helpdesk::TicketField', :through => :section_fields

  validates_presence_of :label
  validates_uniqueness_of :label, :scope => :account_id, :case_sensitive => false

  accepts_nested_attributes_for :section_picklist_mappings, :allow_destroy => true
  accepts_nested_attributes_for :section_fields, :allow_destroy => true

  after_initialize :intialize_options

  after_commit :clear_cache

  xss_sanitize only: [:label], plain_sanitizer: [:label], if: -> { Account.current.ticket_field_revamp_enabled? }

  def intialize_options
    self.options ||= {}
    self.options = self.options.with_indifferent_access
  end

  def parent_ticket_field_id
    # TODO: remove the second part of the code once migration goes live and working
    ticket_field_id || section_picklist_mappings[0].picklist_value.pickable_id
  end
end
