class Helpdesk::ReportFilter < ActiveRecord::Base
  set_table_name "report_filters"

  belongs_to_account

  belongs_to :user

  attr_protected :account_id, :user_id

  serialize :data_hash

  named_scope :by_report_type, lambda { |report_type|
    { :conditions => {:report_type => report_type}}
  }
end
