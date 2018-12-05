class CannedResponseDelegator < BaseDelegator
  include ActiveRecord::Validations
  validate :validate_folder, if: -> { @folder_id }
  validate :validate_group_ids, if: -> { @group_ids }
  validate :validate_personal_folder, if: -> { @visibility }

  def initialize(record, options = {})
    super(record, options)
    @folder_id = options[:folder_id]
    @visibility = options[:visibility]
    @group_ids = options[:group_ids]
    @record = record
  end

  def validate_folder
    folder = Account.current.canned_response_folders.find_by_id(@folder_id.to_i)
    if folder.present?
      if @visibility != Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
        errors[:folder_id] << I18n.t('canned_responses.errors.personal_folder') if folder.personal?
      end
    else
      errors[:folder_id] << I18n.t('canned_responses.errors.invalid_folder_id')
    end
  end

  def validate_group_ids
    group = Account.current.groups_from_cache.collect(&:id)
    @group_ids.each do |group_id|
      errors[:group_id] << I18n.t('canned_responses.errors.invalid_group_id') unless group.include?(group_id.to_i)
    end
  end

  def validate_personal_folder
    if @record.present? && @folder_id.blank?
      access = @record.helpdesk_accessible
      if access.access_type == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
        errors[:folder_id] << I18n.t('canned_responses.errors.required_folder_id') unless @visibility.to_i == Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
      end
    end
  end
end
