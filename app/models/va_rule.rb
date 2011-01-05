class VARule < ActiveRecord::Base
  serialize :filter_data
  serialize :action_data
end
