class Helpdesk::ReportFilter < ActiveRecord::Base
  self.table_name =  "report_filters"
  self.primary_key = :id

  belongs_to_account

  belongs_to :user
  
  has_one :scheduled_task, as: :schedulable, dependent: :destroy

  attr_protected :account_id, :user_id

  serialize :data_hash

  scope :by_report_type, lambda { |report_type|
    { :select => "id, filter_name, data_hash",
      :conditions => {:report_type => report_type},
      :order => 'updated_at DESC'
    }
  }

end
