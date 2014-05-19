class Freshfone::CallMeta < ActiveRecord::Base
  set_table_name :freshfone_calls_meta

  belongs_to_account
  belongs_to :freshfone_call, :class_name => "Freshfone::Call"
  belongs_to :group
end