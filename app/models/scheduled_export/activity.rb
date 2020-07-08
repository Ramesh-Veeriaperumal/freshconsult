class ScheduledExport::Activity < ScheduledExport

  include MemcacheKeys

  attr_accessible :name, :description, :active

  
  after_commit ->(obj) { obj.send_export_message }, on: :update
  after_commit ->(obj) { obj.send_export_message }, on: :create

  after_commit :clear_activity_export_cache

  default_scope -> { where(schedule_type: SCHEDULE_TYPE[:ACTIVITY_EXPORT]) }

  def send_export_message
    if export_activated?
      action = active ? :create : :destroy 
      ScheduledExport::ActivitiesExport.perform_async(action)
    end
  end

  def clear_activity_export_cache
    key = ACCOUNT_ACTIVITY_EXPORT % { :account_id => self.account_id }
    MemcacheKeys.delete_from_cache key
  end

  private

  def export_activated?
    previous_changes[:active].present?
  end

end