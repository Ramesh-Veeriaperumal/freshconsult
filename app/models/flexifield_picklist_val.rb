class FlexifieldPicklistVal < ActiveRecord::Base
  
  belongs_to :flexifield_def_entry
  
  acts_as_list
  
  # scope_condition for acts_as_list
  def scope_condition
    "flexifield_def_entry_id = #{flexifield_def_entry_id}"
  end
  
  def to_s
    value
  end
end
