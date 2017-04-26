class ScheduledExport < ActiveRecord::Base
  include Reports::ScheduledExport::Constants

  self.primary_key = :id

  belongs_to_account
  
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => [:account_id, :schedule_type]
  
end
