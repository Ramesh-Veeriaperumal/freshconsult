class Helpdesk::ReportFilter < ActiveRecord::Base
  self.table_name =  "report_filters"
  self.primary_key = :id

  belongs_to_account

  belongs_to :user
  
  has_one :scheduled_task, as: :schedulable, dependent: :destroy

  attr_protected :account_id, :user_id

  serialize :data_hash, Hash

  scope :by_report_type, ->(report_type){
    where({:report_type => report_type})
    .select('id, filter_name, data_hash')
    .order('updated_at DESC')
  }

end
