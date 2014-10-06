class Helpdesk::PicklistValue < ActiveRecord::Base
  
  belongs_to_account
  self.table_name =  "helpdesk_picklist_values"
  validates_presence_of :value
  validates_uniqueness_of :value, :scope => [:pickable_id, :pickable_type]
  
  belongs_to :pickable, :polymorphic => true

  has_many :sub_picklist_values, :as => :pickable, :class_name => 'Helpdesk::PicklistValue', :include => :sub_picklist_values,
    :dependent => :destroy
  
  acts_as_list
  before_create :set_account_id

  attr_accessible :value, :choices
  # scope_condition for acts_as_list
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

  private
    def set_account_id
      self.account_id = pickable.account_id
    end

end
