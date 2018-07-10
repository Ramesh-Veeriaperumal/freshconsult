class Admin::Sandbox::Job < ActiveRecord::Base
  self.table_name = "admin_sandbox_jobs"

  belongs_to_account
  serialize :additional_data, Hash
  include SandboxConstants
  
  before_create :set_default_values

  def mark_as!(state)
    raise StandardError unless STATUS_KEYS_BY_TOKEN.key?(state)
    self.status = STATUS_KEYS_BY_TOKEN[state]
    self.save!
  end

  STATUS_KEYS_BY_TOKEN.keys.each do |name|
    define_method "#{name}?" do
      self.status == STATUS_KEYS_BY_TOKEN[name.to_sym]
    end
  end

  def mark_shard_as!(state)
    raise StandardError unless ShardMapping::STATUS_CODE.key?(state)
    shard        = ShardMapping.find_by_account_id(self.sandbox_account_id)
    shard.status = ShardMapping::STATUS_CODE[state]
    shard.save!
  end

  def update_last_error(e, state)
    self.last_error =  e.to_s
    mark_as!(state)
  end

  def diff
    self.additional_data[:diff] || {}
  end

  def conflict?
    self.additional_data[:conflict]
  end

  def last_diff
    self.additional_data[:last_diff]
  end

  private

  def set_default_values
    self.status = STATUS_KEYS_BY_TOKEN[:enqueued]
    self.initiated_by = User.current.id
  end

end
