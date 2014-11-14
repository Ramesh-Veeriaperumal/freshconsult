class Helpdesk::ReportFilter < ActiveRecord::Base
  self.table_name =  "report_filters"
  self.primary_key = :id

  belongs_to_account

  belongs_to :user

  attr_protected :account_id, :user_id

  serialize :data_hash

  scope :by_report_type, lambda { |report_type|
    { :conditions => {:report_type => report_type}}
  }
end
