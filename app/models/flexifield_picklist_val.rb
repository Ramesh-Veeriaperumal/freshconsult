class FlexifieldPicklistVal < ActiveRecord::Base
  
  belongs_to :flexifield_def_entry
  
  def to_s
    value
  end
end
