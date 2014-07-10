class Freshfone::Caller < ActiveRecord::Base
  set_table_name :freshfone_callers
  belongs_to_account

  has_many :freshfone_calls, :class_name => "Freshfone::Call", :foreign_key => "caller_number_id"

end