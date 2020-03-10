class CronWebhooksValidation < ApiValidation
  attr_accessor :type, :task_name, :mode, :queue_name, :account_id, :shard_name

  include CronWebhooks::Constants

  validate :validate_type_presence, if: -> { type.present? }
  validate :validate_type_absence, if: -> { type.blank? }
  validates :type, data_type: { rules: String, required: false }, custom_inclusion: { in: TYPES }
  validates :task_name, data_type: { rules: String, required: true }, custom_inclusion: { in: TASKS }
  validates :mode, data_type: { rules: String, required: true }, custom_inclusion: { in: MODES }
  validate :validate_queue_presence, if: -> { queue_name.present? }
  validate :validate_queue_absence, if: -> { queue_name.blank? }
  validates :queue_name, data_type: { rules: String, required: false }, custom_inclusion: { in: MONITORED_QUEUES }
  validate :account_id_presence, if: -> { account_id.present? }
  validate :shard_name_presence, if: -> { shard_name.present? }

  def validate_type_presence
    errors[:type] = :type_not_expected unless TASKS_REQUIRING_TYPES.include? task_name
  end

  def validate_type_absence
    errors[:type] = :type_expected if TASKS_REQUIRING_TYPES.include? task_name
  end

  def validate_queue_presence
    errors[:queue_name] = :queue_name_not_expected unless TASKS_REQUIRING_QUEUE_NAME.include? task_name
  end

  def validate_queue_absence
    errors[:queue_name] = :queue_name_expected if TASKS_REQUIRING_QUEUE_NAME.include? task_name
  end

  def account_id_presence
    errors[:account_id] = :account_id_not_expected unless TASKS_REQUIRING_ACCOUNT_ID.include? task_name
  end

  def shard_name_presence
    errors[:shard_name] = :shard_name_not_expected unless TASKS_REQUIRING_SHARD_NAME.include? task_name
  end
end
