class FlexifieldPicklistVal < ActiveRecord::Base
  self.primary_key = :id
  
  attr_accessible :flexifield_def_entry_id, :value, :position
  
  belongs_to :flexifield_def_entry
  
  acts_as_list :scope => 'flexifield_def_entry_id = #{flexifield_def_entry_id}'
  
  
  def to_s
    value
  end
end
