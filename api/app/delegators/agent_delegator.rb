class AgentDelegator < BaseDelegator
  attr_accessor :group_ids, :role_ids

  validate :validate_group_ids, if: -> { self[:group_ids] }
  validate :validate_role_ids, if: -> { self[:role_ids] }
  validate :validate_avatar_extension, if: -> { @avatar_attachment && errors[:attachment_ids].blank? }

  def initialize(record, options = {})
    options[:attachment_ids] = Array.wrap(options[:avatar_id].to_i) if options[:avatar_id]
    super(record, options)
    @avatar_attachment = @draft_attachments.first if @draft_attachments
  end

  def validate_role_ids
    invalid_roles = self[:role_ids].map(&:to_i) - Account.current.roles_from_cache.map(&:id)
    if invalid_roles.present?
      errors[:role_ids] << :invalid_list
      (@error_options ||= {}).merge!(role_ids: { list: invalid_roles.join(', ') })
    end
  end

  def validate_group_ids
    invalid_groups = self[:group_ids].map(&:to_i) - Account.current.groups_from_cache.map(&:id)
    if invalid_groups.present?
      errors[:group_ids] << :invalid_list
      (@error_options ||= {}).merge!(group_ids: { list: invalid_groups.join(', ') })
    end
  end

  def validate_avatar_extension
    valid_extension, extension = ApiUserHelper.avatar_extension_valid?(@avatar_attachment)
    unless valid_extension
      errors[:avatar_id] << :upload_jpg_or_png_file
      (@error_options ||= {}).merge!(avatar_id: { current_extension: extension })
    end
  end
end
