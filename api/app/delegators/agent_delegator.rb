class AgentDelegator < BaseDelegator
  attr_accessor :group_ids, :role_ids, :available, :user_attributes, :occasional, :agent_type, :agent_level_id

  validate :validate_group_ids, unless: -> { @group_ids.nil? }
  validate :validate_role_ids, :check_role_permission, unless: -> { @role_ids.nil? }
  validate :validate_field_agent_role_ids, if: -> { @role_ids && is_a_field_agent? && errors[:role_ids].blank? }
  validate :validate_avatar_extension, if: -> { @avatar_attachment && errors[:attachment_ids].blank? }
  validate :validate_email_in_freshid, if: -> { @user_attributes && Account.current.freshid_integration_enabled? && @action == 'create' }
  validate :validate_occasional_with_agent_type, if: -> { @occasional && @agent_type && is_a_field_agent? }
  validate :validate_field_agent_groups, if: -> { @agent_type && is_a_field_agent? }
  validate :validate_manage_availability, if: -> { !@available.nil? && @item.present? }
  validate :validate_skill_ids, if: -> { @user_attributes && @user_attributes[:skill_ids] }
  validate :validate_agent_level_id, if: -> { @agent_level_id }

  def initialize(record, options = {})
    @group_ids = options[:group_ids]
    @role_ids = options[:role_ids]
    @available = options[:available]
    @user_attributes = options[:user_attributes]
    @occasional = options[:occasional]
    @agent_type = options[:agent_type]
    @agent_level_id = options[:agent_level_id]
    @item = record
    options[:attachment_ids] = Array.wrap(options[:avatar_id].to_i) if options[:avatar_id]
    super(record, options)
    @avatar_attachment = @draft_attachments.first if @draft_attachments
    @action = options[:action]
  end

  def validate_role_ids
    invalid_roles = @role_ids.map(&:to_i) - Account.current.roles_from_cache.map(&:id)
    if invalid_roles.present?
      errors[:role_ids] << :invalid_list
      (@error_options ||= {}).merge!(role_ids: { list: invalid_roles.join(', ') })
    end
  end

  def validate_field_agent_role_ids
    field_tech_role_id = Account.current.roles_from_cache.find { |role| role.name == Helpdesk::Roles::FIELD_TECHNICIAN_ROLE[:name] }.try(:id)
    invalid_roles = @role_ids - [field_tech_role_id] unless @role_ids.size == 1 && @role_ids.map(&:to_i).first == field_tech_role_id
    if invalid_roles.present?
      err_msg = ErrorConstants::ERROR_MESSAGES[:should_not_have_other_roles] + ': ' + invalid_roles.join(', ')
      errors.add(:role_ids, err_msg)
    end
  end

  def validate_group_ids
    invalid_groups = @group_ids.map(&:to_i) - Account.current.groups_from_cache.map(&:id)
    if invalid_groups.present?
      errors[:group_ids] << :invalid_list
      (@error_options ||= {}).merge!(group_ids: { list: invalid_groups.join(', ') })
    end
  end

  def validate_field_agent_groups
    invalid_groups = @group_ids.map(&:to_i) - fetch_valid_field_agent_groups.map(&:id)
    if invalid_groups.present?
      err_msg = ErrorConstants::ERROR_MESSAGES[:should_not_be_support_group] + ': ' + invalid_groups.join(', ')
      errors.add(:groups_ids, err_msg)
    end
  end

  def validate_skill_ids
    invalid_skills = @user_attributes[:skill_ids] - Account.current.skills_from_cache.collect(&:id)
    duplicate_skills_list = @user_attributes[:skill_ids].select { |skill| @user_attributes[:skill_ids].count(skill) > 1 }.uniq
    if invalid_skills.present?
      errors[:skill_ids] << :invalid_list
      (@error_options ||= {}).merge!(skill_ids: { list: invalid_skills.join(', ') })
    elsif duplicate_skills_list.present?
      errors[:skill_ids] << :duplicate_not_allowed
      (@error_options ||= {}).merge!(name: 'skill_ids', list: duplicate_skills_list.join(', ').to_s)
    end
  end

  def validate_avatar_extension
    valid_extension, extension = ApiUserHelper.avatar_extension_valid?(@avatar_attachment)
    unless valid_extension
      errors[:avatar_id] << :upload_jpg_or_png_file
      (@error_options ||= {}).merge!(avatar_id: { current_extension: extension })
    end
  end

  def validate_manage_availability
    # if the user is account admin or admin, he can toggle regardless of the group has toggle option
    # if the user is supervisor, he should belong to a common group as user. For current user, all of his groups should allow configuring the availability.
    return if User.current.privilege?(:admin_tasks)

    if User.current.privilege?(:manage_availability)
      errors[:available] << :toggle_availability_not_belongs_to_same_group if (User.current.groups.round_robin_groups.pluck(:id) & @item.groups.pluck(:id)).empty?
    elsif User.current.id == @item.user_id
      errors[:available] << :toggle_availability_not_allowed_for_this_user unless @item.toggle_availability?
    else
      errors[:available] << :toggle_availability_error
    end
  end

  def check_role_permission
    return if User.current.privilege?(:manage_account)

    invalid_role_ids = Account.current.roles_from_cache.select { |role| @role_ids.include?(role.id) && role.privilege?(:manage_account) }.map(&:id)
    if invalid_role_ids.present?
      errors[:role_ids] << :access_denied_record_with_list
      (@error_options ||= {}).merge!(list: invalid_role_ids.join(', '), model: 'Agent', column: 'roles')
    end
  end

  def validate_email_in_freshid
    user_details = freshid_user_details @user_attributes['email']
    if user_details.present?
      if !@user_attributes['name'].nil? || !@user_attributes['mobile'].nil? || !@user_attributes['phone'].nil? || !@user_attributes['job_title'].nil?
        errors.add(:name, ErrorConstants::ERROR_MESSAGES[:user_details_present_in_freshid]) if @user_attributes['name'].present?
        errors.add(:mobile, ErrorConstants::ERROR_MESSAGES[:user_details_present_in_freshid]) if @user_attributes['mobile'].present?
        errors.add(:phone, ErrorConstants::ERROR_MESSAGES[:user_details_present_in_freshid]) if @user_attributes['phone'].present?
        errors.add(:job_title, ErrorConstants::ERROR_MESSAGES[:user_details_present_in_freshid]) if @user_attributes['job_title'].present?
      end
    end
  end

  def validate_occasional_with_agent_type
    errors[:occasional] << :occasional_is_not_true_for_field_agent if @occasional == true
  end

  def validate_agent_level_id
    if (@action == 'create' || @action == 'update') && scoreboard_levels.find_by_id(@agent_level_id).blank?
      errors[:agent_level_id] << :invalid_agent_level_id
    elsif @action == 'update'
      scoreboard_level_id = Account.current.agents.find_by_user_id(@user_attributes['id']).try(:scoreboard_level_id)
      scoreboard_level = scoreboard_levels.find_by_id(scoreboard_level_id)
      allowable_ids = scoreboard_levels.level_up_for scoreboard_level
      errors[:agent_level_id] << :incorrect_agent_level_id unless allowable_ids.map(&:id).include?(@agent_level_id)
    end
  end

  private

    def freshid_user_details(email)
      Account.current.freshid_org_v2_enabled? ? Freshid::V2::Models::User.find_by_email(email.to_s) : Freshid::User.find_by_email(email.to_s)
    end

    def is_a_field_agent?
      Account.current.field_service_management_enabled? && @agent_type == Account.current.agent_types.find_by_name(Agent::FIELD_AGENT).agent_type_id
    end

    def fetch_valid_field_agent_groups
      agent_type_name = AgentType.agent_type_name(@agent_type)
      group_type_name = Agent::AGENT_GROUP_TYPE_MAPPING[agent_type_name]
      group_type_id = GroupType.group_type_id(group_type_name)
      Account.current.groups_from_cache.select { |group| group.group_type == group_type_id }
    end

    def scoreboard_levels
      Account.current.scoreboard_levels
    end
end
