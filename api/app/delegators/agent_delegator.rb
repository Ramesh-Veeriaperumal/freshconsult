class AgentDelegator < BaseDelegator
  attr_accessor :group_ids, :role_ids

  validate :validate_group_ids, if: -> { self[:group_ids] }
  validate :validate_role_ids, :check_role_permission, if: -> { self[:role_ids] }
  validate :validate_avatar_extension, if: -> { @avatar_attachment && errors[:attachment_ids].blank? }
  validate :validate_email_in_freshid, if: -> { self[:user_attributes] && Account.current.freshid_integration_enabled? }
  validate :validate_occasional_with_agent_type, if: -> { self[:occasional] && self[:agent_type] && is_a_field_agent? }
  validate :validate_field_agent_groups, if: -> { self[:agent_type] && is_a_field_agent? }

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

  def validate_field_agent_groups
    invalid_groups = self[:group_ids].map(&:to_i) - fetch_valid_field_agent_groups.map(&:id)
    if invalid_groups.present?
      err_msg = ErrorConstants::ERROR_MESSAGES[:should_not_be_support_group] + ': ' + invalid_groups.join(', ')
      self.errors.add(:groups_ids, err_msg)
    end
  end

  def validate_avatar_extension
    valid_extension, extension = ApiUserHelper.avatar_extension_valid?(@avatar_attachment)
    unless valid_extension
      errors[:avatar_id] << :upload_jpg_or_png_file
      (@error_options ||= {}).merge!(avatar_id: { current_extension: extension })
    end
  end

  def check_role_permission
    return if User.current.privilege?(:manage_account)

    invalid_role_ids = Account.current.roles_from_cache.select { |role| self[:role_ids].include?(role.id) && role.privilege?(:manage_account) }.map(&:id)
    if invalid_role_ids.present?
      errors[:role_ids] << :access_denied_record_with_list
      (@error_options ||= {}).merge!(list: invalid_role_ids.join(', '), model: 'Agent', column: 'roles')
    end
  end

  def validate_email_in_freshid
    user_details = freshid_user_details self['user_attributes']['email']
    if user_details.present?
      if !self['user_attributes']['name'].nil? || !self['user_attributes']['mobile'].nil? || !self['user_attributes']['phone'].nil? || !self['user_attributes']['job_title'].nil?
        self.errors.add(:name, ErrorConstants::ERROR_MESSAGES[:user_details_present_in_freshid]) if self['user_attributes']['name'].present?
        self.errors.add(:mobile, ErrorConstants::ERROR_MESSAGES[:user_details_present_in_freshid]) if self['user_attributes']['mobile'].present?
        self.errors.add(:phone, ErrorConstants::ERROR_MESSAGES[:user_details_present_in_freshid]) if self['user_attributes']['phone'].present?
        self.errors.add(:job_title, ErrorConstants::ERROR_MESSAGES[:user_details_present_in_freshid]) if self['user_attributes']['job_title'].present?
      end
    end
  end

  def validate_occasional_with_agent_type
    if self[:occasional] == true
      errors[:occasional] << :occasional_is_not_true_for_field_agent
    end
  end

  private

    def freshid_user_details(email)
      Account.current.freshid_org_v2_enabled? ? Freshid::V2::Models::User.find_by_email(email.to_s) : Freshid::User.find_by_email(email.to_s)
    end

    def is_a_field_agent?
      Account.current.field_service_management_enabled? && self[:agent_type] == Account.current.agent_types.find_by_name(Agent::FIELD_AGENT).agent_type_id
    end

    def fetch_valid_field_agent_groups
      agent_type_name = AgentType.agent_type_name(self[:agent_type])
      group_type_name = Agent::AGENT_GROUP_TYPE_MAPPING[agent_type_name]
      group_type_id = GroupType.group_type_id(group_type_name)
      Account.current.groups_from_cache.select { |group| group.group_type == group_type_id }
    end
end
