class ScheduledExport < ActiveRecord::Base
  include Reports::ScheduledExport::Constants

  self.primary_key = :id

  belongs_to_account

  belongs_to :user

  attr_accessible :name, :description

  before_validation :remove_whitespaces

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => [:account_id, :schedule_type], :case_sensitive => false

  private
    def remove_whitespaces
      name.strip!
    end

end
