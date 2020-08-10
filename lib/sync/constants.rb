module Sync::Constants

  FILE_EXTENSION       =  ".txt"
  IGNORE_ASSOCIATIONS  =  ["id", "account_id", "updated_at", "tag_uses_count", "ticket_form_id", "content_updated_at"] # Will remove ticket_form_id after adding association
  UPDATE_ASSOCIATIONS  =  ["updated_at"]
  MAPPING_TABLE_NAME = 'mapping_table'

  IGNORE_RELATIONS_TO_PRODUCTION = ["agents"].freeze

  RELATIONS            = [
    # ["account_additional_settings", []],
    # ["account_configuration", []],
    ["agent_password_policy",        []],
    ["contact_password_policy",      []],
    ["all_va_rules",                 []],
    ["all_supervisor_rules",         []],
    ["all_observer_rules",           []],
    ["ticket_templates",             [{:accessible => [:group_accesses, :user_accesses]}, {:shared_attachments => [:attachment]}, :attachments, :cloud_files, :parents, :children, :child_templates, :parent_templates]],
    ["canned_response_folders",      []],
    ["canned_responses",             [{:helpdesk_accessible => [:group_accesses, :user_accesses]}, {:shared_attachments => [:attachment]}]],
    ["scn_automations",              [{:accessible => [:group_accesses, :user_accesses]}]],
    ["ticket_field_def",             []],
    # This association includes both normal, archived Ticket Fields
    ['ticket_fields_with_archived_fields', [:ticket_statuses, :child_levels, :flexifield_def_entry, { section_fields: [{ section: [{ section_picklist_mappings: [:picklist_value] }] }, { parent_ticket_field: [:flexifield_def_entry] }] }, { picklist_values: [{ sub_picklist_values: [{ sub_picklist_values: [] }] }] }, { nested_ticket_fields: [:flexifield_def_entry] }]],
    ['agent_types',                  []],
    ["agents",                       [:agent_groups, {:user => [:user_emails, :user_roles, :avatar, :user_skills, :forum_moderator]}]],
    ['group_types',                  []],
    ["groups",                       []],
    ['helpdesk_sources',             []],
    ["roles",                        []],
    ["tags",                         []],
    ["business_calendar",            []],
    ["sla_policies",                 [:sla_details]],
    ["email_notifications",          [:dynamic_notification_templates, :email_notification_agents]],
    ["contact_form",                 [{:all_fields => [:custom_field_choices]}]],
    ["company_form",                 [{:all_fields => [:custom_field_choices]}]],
    ["custom_surveys",               [{:all_fields => [:custom_field_choices]}]],
    ["status_groups",                []],
    ["skills",                       []],
    ["helpdesk_permissible_domains", []],
    ["products",                     []]
  ]

  CLONE_RELATIONS       = [
    ['twitter_handles',               [{ twitter_streams: [:filter_rules, { accessible: [:group_accesses, :user_accesses] }] }, :avatar]],
    ['custom_twitter_streams',        [:ticket_rules, { accessible: [:group_accesses, :user_accesses] }]]
  ]

  ASSOCIATIONS_TO_REINDEX = [
    "scn_automations",
    "canned_responses",
    "ticket_templates"
  ]

  MODEL_INSERT_ORDER = MODEL_DEPENDENCIES.keys

  account_association = [["Account"], "account_id"]
  # Adding account association to all the models.
  MODEL_DEPENDENCIES.keys.each do |model|
    MODEL_DEPENDENCIES[model] << account_association
  end

  #TODO: Move to a class which does all Post migration activities
  POST_MIGRATION_ACTIVITIES = {
    "Helpdesk::Attachment" => lambda { |master_account_id, mapping_table = {}, resync = false|
      mapping_data = mapping_table["Helpdesk::Attachment"][:id]
      account = Account.current
      account.attachments.where({:id  => mapping_data.values}).each do |attachment|
        source_attachment_path      = Helpdesk::Attachment.s3_path(mapping_data.key(attachment.id), attachment.content_file_name)
        destination_attachment_path = Helpdesk::Attachment.s3_path(attachment.id, attachment.content_file_name)
         # p "source Attachment Path : #{source_attachment_path}\n"
         # p "dest : #{destination_attachment_path}"
        begin
          AwsWrapper::S3.copy(source_attachment_path, S3_CONFIG[:bucket], destination_attachment_path) # PRE-RAILS: Needs to be checked
          attachment.content.reprocess!
        rescue => e
          puts "Error while moving attachment for #{attachment.inspect} . Source Attachment ID: #{mapping_data[attachment.id]} Destination Attachment ID : #{attachment.id}"
          puts "Error - #{e}"
        end
      end
    },
    "Group"  => lambda { |master_account_id, mapping_table = {}, resync = false|
      return if resync
      account = Account.current
      users_mapping_data = mapping_table["User"][:id]
      account.groups.where('escalate_to IS NOT  ?', nil).each do|group|
        group.escalate_to = users_mapping_data[group.escalate_to]
        group.save
      end
    }
  }

  MODEL_MEMCACHE_KEYS = {
    'HelpdeskPermissibleDomain' => ['clear_helpdesk_permissible_domains_from_cache'],
    'Product'                   => ['clear_fragment_caches', 'clear_cache'],
    'Admin::Skill'              => ['clear_skills_cache'],
    'Helpdesk::TicketField'     => ['clear_cache', 'clear_new_ticket_field_cache', 'clear_fragment_caches', 'clear_all_section_ticket_fields_cache']
  }.freeze

  ACCOUNT_MEMCACHE_KEYS = [
    "clear_contact_password_policy_from_cache", 
    "clear_agent_password_policy_from_cache",
    "clear_ticket_types_from_cache",
    "clear_account_status_groups_cache"
  ]

  # Merge will follow this order. Modified files will use added files id. So, we insert added first.
  MERGE_FILES_TYPES = [
      :added,
      :modified,
      :deleted
  ].freeze

  GIT_ROOT_PATH        = "#{Rails.root}/tmp/sandbox"
  RESYNC_ROOT_PATH    = "#{Rails.root}/tmp/resync"

  LOGO_MAP = {
    "agent_password_policy"        => "security",
    "contact_password_policy"      => "security",
    "ticket_field_def"             => "ticket_fields",
    "canned_response_folders"      => "canned_responses",
    "status_groups"                => "groups",
    "company_form"                 => "contact_form",
    "helpdesk_permissible_domains" => "helpdesk"
  }

  SKIP_SYMBOLIZE_KEYS = {
    'Helpdesk::TicketTemplate' => ['template_data'],
    'PasswordPolicy' => ['configs'],
    'Helpdesk::TicketField' => ['field_options'],
    'Helpdesk::SlaDetail' => ['sla_target_time'],
    'Helpdesk::SlaPolicy' => ['conditions', 'escalations'],
    'Helpdesk::Section' => ['options'],
    'Helpdesk::Choice' => ['meta'],
    'Agent' => ['additional_settings']
  }.freeze

  UNIQUE_MODEL_DATA = {
    'all_va_rules' => ['VaRule', ['name', 'rule_type']],
    'all_observer_rules' => ['VaRule', ['name', 'rule_type']],
    'all_supervisor_rules' => ['VaRule', ['name', 'rule_type']],
    'ticket_fields_with_archived_fields' => ['Helpdesk::TicketField', ['name'], true],
    'contact_form' => ['ContactField', ['name', 'contact_form_id'], true],
    'company_form' => ['CompanyField', ['name', 'company_form_id'], true],
    'groups' => ['Group', ['name']],
    'products' => ['Product', ['name']],
    'canned_response_folders' => ['Admin::CannedResponses::Folder', ['name']],
    'sla_policies' => ['Helpdesk::SlaPolicy', ['name']],
    'skills' => ['Admin::Skill', ['name']],
    'ticket_templates' => ['Helpdesk::TicketTemplate', ['name']],
    'canned_responses' => ['Admin::CannedResponses::Response', ['title', 'folder_id']],
    'roles' => ['Role', ['name']]
  }.freeze

  # In UI the diff data was identified using a translation file where the translation names were the names
  # of the associations in RELATIONS. So changing the association breaks the translation in UI.
  # Example: To support archive_ticket_fields feature in sanbox we changed the association 'ticket_fields' to 'ticket_fields_with_archived_fields'
  # due to which the translation got broken. So this constant will contain translation mapping for the respective association.
  # This will be used in diff api response. We will replace the assciation mapping with translation mapping there.
  TRANSLATION_DATA = {
    'ticket_fields_with_archived_fields': 'ticket_fields'
  }.freeze

  FORM_BASED_MODELS = ['contact_form', 'company_form'].freeze

  IGNORE_SOFT_DELETE_TABLES = %w[helpdesk_ticket_fields helpdesk_picklist_values flexifield_def_entries helpdesk_choices].freeze

end
