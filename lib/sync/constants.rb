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
    ["features",                     []],
    ["all_va_rules",                 []],
    ["all_supervisor_rules",         []],
    ["all_observer_rules",           []],
    ["ticket_templates",             [{:accessible => [:group_accesses, :user_accesses]}, {:shared_attachments => [:attachment]}, :attachments, :cloud_files, :parents, :children, :child_templates, :parent_templates]],
    ["canned_response_folders",      []],
    ["canned_responses",             [{:helpdesk_accessible => [:group_accesses, :user_accesses]}, {:shared_attachments => [:attachment]}]],
    ["scn_automations",              [{:accessible => [:group_accesses, :user_accesses]}]],
    ["ticket_field_def",             []],
    ["ticket_fields",                [:ticket_statuses, :child_levels, :flexifield_def_entry, {:section_fields => [{:section => [{:section_picklist_mappings => [:picklist_value]}]},  { :parent_ticket_field => [:flexifield_def_entry]}]},  {:picklist_values => [{:sub_picklist_values => [{:sub_picklist_values => []}]}]}, {:nested_ticket_fields => [:flexifield_def_entry]}]],
    ["agents",                       [:agent_groups, {:user => [:user_emails, :user_roles, :avatar, :user_skills, :forum_moderator]}]],
    ["groups",                       []],
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
          AwsWrapper::S3Object.copy_file(source_attachment_path, destination_attachment_path, S3_CONFIG[:bucket])
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
    'Admin::Skill'              => ['clear_skills_cache']
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
    'Helpdesk::TicketField' => ['field_options']
  }

end
