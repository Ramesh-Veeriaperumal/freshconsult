class Helpdesk::PicklistValue < ActiveRecord::Base
  
  belongs_to_account
  self.table_name =  "helpdesk_picklist_values"
  validates_presence_of :value
  validates_uniqueness_of :value, :scope => [:pickable_id, :pickable_type, :account_id], :if => 'pickable_id.present?'
  
  belongs_to :pickable, :polymorphic => true

  has_many :sub_picklist_values, :as => :pickable, 
                                 :class_name => 'Helpdesk::PicklistValue', 
                                 :include => :sub_picklist_values,
                                 :dependent => :destroy,
                                 :order => "position"

  has_one :section_picklist_mapping, :class_name => 'Helpdesk::SectionPicklistValueMapping', 
                                     :dependent => :destroy
  has_one :section, :class_name => 'Helpdesk::Section', :through => :section_picklist_mapping

  attr_accessible :value, :choices, :position

  accepts_nested_attributes_for :sub_picklist_values, :allow_destroy => true
  
  before_create :set_account_id
  
  # scope_condition for acts_as_list and as well for using index in fetching sub_picklist_values
  def scope_condition
    "pickable_id = #{pickable_id} AND #{connection.quote_column_name("pickable_type")} = 
    '#{pickable_type}'"
  end

  def choices=(c_attr)
    sub_picklist_values.clear
    c_attr.each_with_index do |c, index| 
      if c.size > 2 && c[2].is_a?(Array)
        sub_picklist_values.build({:value => c[0], :position => index+1, :choices => c[2]})
      else
        sub_picklist_values.build({:value => c[0], :position => index+1})
      end
    end  
  end

  def section_ticket_fields
    section_tkt_fields = []
    unless section.blank?
      picklist_section_fields = section.section_fields
      picklist_section_fields.each do |section_field|
        section_tkt_fields.push(section_field.ticket_field)
      end
    end
    section_tkt_fields
  end

  def choices
    sub_picklist_values.collect { |c| [c.value, c.value]}
  end

  def self.with_exclusive_scope(method_scoping = {}, &block) # for account_id in sub_picklist_values query
    with_scope(method_scoping, :overwrite, &block)
  end

  private
    def set_account_id
      self.account_id = pickable.account_id
    end

end
