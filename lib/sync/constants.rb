module Sync::Constants

  FILE_EXTENSION       =  ".txt"
  IGNORE_ASSOCIATIONS  =  ["id", "account_id", "updated_at", "tag_uses_count"]
  UPDATE_ASSOCIATIONS  =  ["updated_at"]

  BRANCH_PREFIX        = "d-"

  RELATIONS            = [
    # ["account_additional_settings", []],
    # ["account_configuration", []],
    ["agent_password_policy",        []],
    ["contact_password_policy",      []],
    ["features",                     []],
    ["all_va_rules",                 []],
    ["all_supervisor_rules",         []],
    ["all_observer_rules",           []],
    ["ticket_templates",             [{:accessible => [:group_accesses, :user_accesses]}, {:shared_attachments => [:attachment]}, :attachments, :cloud_files]],
    ["canned_response_folders",      [{:canned_responses => [{:helpdesk_accessible => [:group_accesses, :user_accesses]}, {:shared_attachments => [:attachment]}]}]],
    ["scn_automations",              [{:accessible => [:group_accesses, :user_accesses]}]],
    ["ticket_field_def",             []],
    ["ticket_fields",                [:ticket_statuses, :child_levels, :flexifield_def_entry, {:section_fields => [{:section => [{:section_picklist_mappings => [:picklist_value]}]}]},  {:picklist_values => [{:sub_picklist_values => [{:sub_picklist_values => []}]}]}, {:nested_ticket_fields => [:flexifield_def_entry]}]],
    ["agents",                       [:agent_groups, {:user => [:user_emails, :user_roles, :avatar]}]],
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
    ["helpdesk_permissible_domains", []],
    ["products",                     []]
  ]

  ASSOCIATIONS_TO_REINDEX = [
    "scn_automations",
    "canned_responses",
    "ticket_templates"
  ]

  #TODO: Move to a class which does all Post migration activities
  POST_MIGRATION_ACTIVITIES = {
    "Helpdesk::Attachment" => lambda { |master_account_id, mapping_data = {}|
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
      Helpdesk::SharedAttachment.where(["attachment_id in (?)", mapping_data.keys]).each do |att|
        att.attachment_id = mapping_data[att.attachment_id]
        att.save
      end
    }
  }

  MODEL_MEMCACHE_KEYS = {
    "Features::Feature"         => ["clear_features_from_cache"],
    "HelpdeskPermissibleDomain" => ["clear_helpdesk_permissible_domains_from_cache"],
    "Product"                   => ["clear_fragment_caches", "clear_cache"]
  }

  ACCOUNT_MEMCACHE_KEYS = [
    "clear_contact_password_policy_from_cache", 
    "clear_agent_password_policy_from_cache",
    "clear_ticket_types_from_cache",
    "clear_account_status_groups_cache"
  ]

  GIT_ROOT_PATH        = "#{Rails.root}/tmp/sandbox"  
  
end
