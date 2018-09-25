class Helpdesk::PicklistValue < ActiveRecord::Base
  
  clear_memcache [ACCOUNT_SECTION_FIELDS_WITH_FIELD_VALUE_MAPPING,TICKET_FIELDS_FULL]

  belongs_to_account
  self.table_name =  "helpdesk_picklist_values"
  validates_presence_of :value
  validates_uniqueness_of :value, :scope => [:pickable_id, :pickable_type, :account_id], :if => 'pickable_id.present?'

  attr_accessor :required_ticket_fields, :section_ticket_fields
  
  belongs_to :pickable, :polymorphic => true

  has_many :sub_picklist_values, :as => :pickable, 
                                 :class_name => 'Helpdesk::PicklistValue', 
                                 :dependent => :destroy,
                                 :order => "position"

  has_one :section_picklist_mapping, :class_name => 'Helpdesk::SectionPicklistValueMapping', 
                                     :dependent => :destroy
  has_one :section, :class_name => 'Helpdesk::Section', :through => :section_picklist_mapping

  attr_accessible :value, :choices, :position

  accepts_nested_attributes_for :sub_picklist_values, :allow_destroy => true
  
  before_validation :trim_spaces, :if => :value_changed?


  CACHEABLE_ATTRIBUTES = ["id", "account_id", "pickable_id", "pickable_type", "value", "position", "created_at", "updated_at"]
  
  # scope_condition for acts_as_list and as well for using index in fetching sub_picklist_values
  def scope_condition
    "pickable_id = #{pickable_id} AND #{connection.quote_column_name("pickable_type")} = 
    '#{pickable_type}'"
  end

  def custom_cache_attributes
    {
      :section_ticket_fields => section_ticket_fields
    }
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

  def required_ticket_fields
    @required_ticket_fields ||= filter_fields section_ticket_fields
  end

  def section_ticket_fields
    @section_ticket_fields ||= (section.present?) ? section.section_fields.map(&:ticket_field) : []
  end

  def choices
    sub_picklist_values.collect { |c| [c.value, c.value]}
  end 

  def self.with_exclusive_scope(method_scoping = {}, &block) # for account_id in sub_picklist_values query
    with_scope(method_scoping, :overwrite, &block)
  end


  private

    def filter_fields fields
      fields.select {|field| field.required_for_closure? }
    end

    def trim_spaces
      value.to_s.strip!
    end

end
