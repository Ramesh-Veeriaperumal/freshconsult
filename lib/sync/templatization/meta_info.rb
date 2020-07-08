module Sync::Templatization::MetaInfo
  include Sync::Constants
  include Sync::Templatization::Constant
  DEFAULT_META_INFO = ['va_rule', 'admin_skill', 'admin_canned_responses_folder', 'scenario_automation',
                       'group', 'role', 'helpdesk_tag', 'helpdesk_sla_policy', 'product', 'business_calendar'].freeze

  def password_policy_meta_info(dir_path)
    {
      name: PasswordPolicy::USER_TYPE.index(get_value(dir_path, 'user_type'))
    }
  end

  def hash_id(path)
    (MERGE_FILES_TYPES + [:conflict]).each do |type|
      hash_id = diff_changes[type].try(:[], path).try(:[], INDEX_VALUE_BY_ACTION_TYPE[type])
      return hash_id if hash_id
    end
    nil
  end

  def load_file(file)
    Syck.load_file(file) if File.exist?(file)
  end

  def get_value(dir_path, column)
    git_path = File.join(dir_path.gsub("#{resync_root_path}/", ''), "#{column}.txt")
    hash_id = hash_id(git_path)
    if hash_id
      load_yaml_from_hash(hash_id)
    else
      file = File.join(replace_resync_with_root_path(dir_path), "/#{column}.txt")
      return load_file(file) if File.exist?(file)
      load_file(File.join(replace_resync_with_sandbox_root_path(dir_path), "/#{column}.txt"))
    end
  end

  DEFAULT_META_INFO.each do |model|
    define_method "#{model}_meta_info" do |dir_path|
      { name: get_value(dir_path, 'name') }
    end
  end

  def admin_canned_responses_response_meta_info(dir_path)
    {
      name: get_value(dir_path, 'title'),
      folder: get_value(File.dirname(File.dirname(dir_path)), 'name')
    }
  end

  def helpdesk_ticket_template_meta_info(dir_path)
    {
      name: get_value(dir_path, 'name'),
      type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TYPE[get_value(dir_path, 'association_type').to_i]
    }
  end

  def helpdesk_ticket_field_meta_info(dir_path)
    {
      name: get_value(dir_path, 'label'),
      type:  get_value(dir_path, 'field_type')
    }.merge!(ticket_field_section_meta_info(dir_path))
  end

  def section_field_meta_info(dir_path)
    section_meta_info = {}
    ticket_field_id = transform_by_action(File.basename(dir_path).to_i)
    section_field = @acc.section_fields.find_by_ticket_field_id(ticket_field_id)
    section_meta_info[:label] = @acc.sections.find_by_id(section_field.section_id).label
    section_meta_info[:parent_name] = @acc.ticket_fields.find_by_id(section_field.parent_ticket_field_id).label
    { section: section_meta_info }
  end

  def ticket_field_section_meta_info(dir_path)
    field_options = get_value(dir_path, 'field_options')
    return {} if field_options && !field_options.symbolize_keys.key?(:section)
    # If it is deleted fetch from production else fetch from sandbox
    select_shard_and_slave(account_by_action) { section_field_meta_info(dir_path) }
  rescue Exception => e
    Rails.logger.error("******* Sandbox resync templatization in section_field_meta_info account id #{account.id} #{e}")
    {}
  end

  def email_notification_meta_info(dir_path)
    notification_type = get_value(dir_path, 'notification_type')
    {
      name: EmailNotification::TOKEN_BY_KEY[notification_type.to_i].to_s
    }
  end

  def contact_form_meta_info(dir_path)
    {
      name: get_value(dir_path, 'label'),
      type:  ContactField::FIELD_TYPE_NUMBER_TO_NAME[get_value(dir_path, 'field_type').to_i]
    }
  end

  def company_form_meta_info(dir_path)
    {
      name: get_value(dir_path, 'label'),
      type:  CompanyField::FIELD_TYPE_NUMBER_TO_NAME[get_value(dir_path, 'field_type').to_i]
    }
  end

  def custom_survey_survey_meta_info(dir_path)
    {
      name: get_value(dir_path, 'title_text'),
      default_survey_question_id: select_shard_and_slave(sandbox_account_id) { default_survey_question_id(dir_path) }
    }
  end

  def default_survey_question_id(dir_path)
    sandbox_survey_question_id = @acc.custom_surveys.find_by_id(transform_id_to_sandbox_accounts_id(File.basename(dir_path).to_i)).all_fields.find_by_default(1).id
    transform_id_to_production_accounts_id(sandbox_survey_question_id)
  end

  def helpdesk_permissible_domain_meta_info(dir_path)
    {
      name: get_value(dir_path, 'domain')
    }
  end

  def status_group_meta_info(dir_path)
    group_id = get_value(dir_path, 'group_id')
    status_id = get_value(dir_path, 'status_id')
    {
      status:  select_shard_and_slave(account_by_action) { @acc.ticket_statuses.find_by_id(transform_by_action(status_id)).name },
      group: select_shard_and_slave(account_by_action) { @acc.groups.find_by_id(transform_by_action(group_id)).name }
    }
  end

  def account_by_action
    action == :deleted ? account.id : sandbox_account_id
  end

  def transform_by_action(item_id)
    action == :deleted ? item_id : transform_id_to_sandbox_accounts_id(item_id)
  end

  def transform_id_to_sandbox_accounts_id(item_id)
    @transformer.apply_id_mapping(item_id, {}, '', true)
  end

  def transform_id_to_production_accounts_id(item_id)
    @transformer.apply_id_mapping(item_id)
  end
end
