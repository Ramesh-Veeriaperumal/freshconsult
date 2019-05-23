class Admin::Sandbox::Job < ActiveRecord::Base
  self.table_name = "admin_sandbox_jobs"
  
  before_create :set_default_values
  
  STATUSES = [
    [:enqueued,           1],
    [:sync_from_prod,     2],
    [:provision_staging,  3],
    [:complete,           4]
  ]

  STATUS_KEYS_BY_TOKEN = Hash[*STATUSES.map { |i| [i[0], i[1]] }.flatten]
  
  def set_default_values
    self.status       = STATUS_KEYS_BY_TOKEN[:enqueued]
    self.initiated_by = User.current.id
  end
  
  def sync_from_prod
    self.status = STATUS_KEYS_BY_TOKEN[:sync_from_prod]
    self.save
  end
  
  def provision_staging
    self.status = STATUS_KEYS_BY_TOKEN[:provision_staging]
    self.save
  end
  
  def complete
    self.status = STATUS_KEYS_BY_TOKEN[:complete]
    self.save
  end
  
  def set_sandbox_to_maintainance_mode
    shard        = ShardMapping.find_by_account_id(self.sandbox_account_id)
    shard.status = ShardMapping::STATUS_CODE[:maintenance]
    shard.save
  end
  
  def set_sandbox_to_partial
    shard        = ShardMapping.find_by_account_id(self.sandbox_account_id)
    shard.status = ShardMapping::STATUS_CODE[:partial]
    shard.save
  end
  
  def set_sandbox_to_live
    shard        = ShardMapping.find_by_account_id(self.sandbox_account_id)
    shard.status = ShardMapping::STATUS_CODE[:ok]
    shard.save
  end
  
end
