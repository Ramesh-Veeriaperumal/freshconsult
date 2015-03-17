class Helpdesk::PicklistValue < ActiveRecord::Base
  
  belongs_to_account
  self.table_name =  "helpdesk_picklist_values"
  validates_presence_of :value
  validates_uniqueness_of :value, :scope => [:pickable_id, :pickable_type, :account_id]
  
  belongs_to :pickable, :polymorphic => true

  has_many :sub_picklist_values, :as => :pickable, :class_name => 'Helpdesk::PicklistValue', :include => :sub_picklist_values,
    :dependent => :destroy
  
  attr_accessible :value, :choices, :position
  
  acts_as_list :scope => 'pickable_id = #{pickable_id} AND #{connection.quote_column_name("pickable_type")} = 
   \'#{pickable_type}\''
  before_create :set_account_id
  
  # scope_condition for acts_as_list and as well for using index in fetching sub_picklist_values
  def scope_condition
    "pickable_id = #{pickable_id} AND #{connection.quote_column_name("pickable_type")} = 
    '#{pickable_type}'"
  end

  def choices=(c_attr)
    sub_picklist_values.clear
    c_attr.each do |c| 
      if c.size > 2 && c[2].is_a?(Array)
        sub_picklist_values.build({:value => c[0], :choices => c[2]})
      else
        sub_picklist_values.build({:value => c[0]})
      end
    end  
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
