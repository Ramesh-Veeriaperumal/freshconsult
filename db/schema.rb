# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130720072935) do

  create_table "account_additional_settings", :force => true do |t|
    t.string   "email_cmds_delimeter"
    t.integer  "account_id",           :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "ticket_id_delimiter",               :default => "#"
    t.boolean  "pass_through_enabled",              :default => true
    t.string   "bcc_email"
  end

  add_index "account_additional_settings", ["account_id"], :name => "index_account_id_on_account_additional_settings"

  create_table "account_configurations", :force => true do |t|
    t.integer  "account_id",     :limit => 8, :null => false
    t.text     "contact_info"
    t.text     "billing_emails"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "account_configurations", ["account_id"], :name => "index_for_account_configurations_on_account_id"

  create_table "accounts", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "full_domain"
    t.string   "time_zone"
    t.string   "helpdesk_name"
    t.integer  "ticket_display_id", :limit => 8, :default => 0
    t.boolean  "sso_enabled",                    :default => false
    t.string   "shared_secret"
    t.text     "sso_options"
    t.string   "google_domain"
    t.boolean  "ssl_enabled",                    :default => false
    t.boolean  "premium",                        :default => false
  end

  add_index "accounts", ["full_domain"], :name => "index_accounts_on_full_domain", :unique => true
  add_index "accounts", ["time_zone"], :name => "index_accounts_on_time_zone"

  create_table "achieved_quests", :force => true do |t|
    t.integer  "user_id",    :limit => 8
    t.integer  "account_id", :limit => 8
    t.integer  "quest_id",   :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "achieved_quests", ["quest_id", "account_id"], :name => "index_achieved_quests_on_quest_id_and_account_id"
  add_index "achieved_quests", ["user_id", "account_id", "quest_id"], :name => "index_achieved_quests_on_user_id_account_id_quest_id", :unique => true

  create_table "addresses", :force => true do |t|
    t.string   "first_name"
    t.string   "last_name"
    t.text     "address1"
    t.text     "address2"
    t.string   "country"
    t.string   "state"
    t.string   "city"
    t.string   "zip"
    t.integer  "account_id",       :limit => 8
    t.integer  "addressable_id",   :limit => 8
    t.string   "addressable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "admin_canned_responses", :force => true do |t|
    t.string   "title"
    t.text     "content",      :limit => 2147483647
    t.integer  "account_id",   :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "content_html", :limit => 2147483647
    t.integer  "folder_id",    :limit => 8
  end

  add_index "admin_canned_responses", ["account_id", "folder_id", "title"], :name => "Index_ca_responses_on_account_id_folder_id_and_title", :length => {"folder_id"=>nil, "account_id"=>nil, "title"=>"20"}

  create_table "admin_data_imports", :force => true do |t|
    t.string   "import_type"
    t.boolean  "status"
    t.integer  "account_id",  :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "admin_data_imports", ["account_id", "created_at"], :name => "index_data_imports_on_account_id_and_created_at"

  create_table "admin_user_accesses", :force => true do |t|
    t.string   "accessible_type"
    t.integer  "accessible_id"
    t.integer  "user_id",         :limit => 8
    t.integer  "visibility",      :limit => 8
    t.integer  "group_id",        :limit => 8
    t.integer  "account_id",      :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "admin_user_accesses", ["account_id", "accessible_type", "accessible_id"], :name => "index_admin_user_accesses_on_account_id_and_acc_type_and_acc_id"
  add_index "admin_user_accesses", ["user_id"], :name => "index_admin_user_accesses_on_user_id"

  create_table "agent_groups", :force => true do |t|
    t.integer  "user_id",    :limit => 8
    t.integer  "group_id",   :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id", :limit => 8
  end

  add_index "agent_groups", ["account_id", "user_id", "group_id"], :name => "index_agent_groups_on_account_id_and_user_id_and_group_id"
  add_index "agent_groups", ["group_id", "user_id"], :name => "agent_groups_group_user_ids"

  create_table "agents", :force => true do |t|
    t.integer  "user_id",             :limit => 8
    t.text     "signature"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "ticket_permission",                :default => 1
    t.boolean  "occasional",                       :default => false
    t.string   "google_viewer_id"
    t.text     "signature_html"
    t.integer  "points",              :limit => 8
    t.integer  "scoreboard_level_id", :limit => 8
    t.integer  "account_id",          :limit => 8
    t.boolean  "available",                        :default => true
  end

  add_index "agents", ["account_id", "user_id"], :name => "index_agents_on_account_id_and_user_id"

  create_table "app_business_rules", :force => true do |t|
    t.integer "va_rule_id",     :limit => 8
    t.integer "application_id", :limit => 8
  end

  create_table "applications", :force => true do |t|
    t.string  "name"
    t.string  "display_name"
    t.string  "description"
    t.integer "listing_order"
    t.text    "options"
    t.integer "account_id",       :default => 0
    t.string  "application_type", :default => "freshplug", :null => false
  end

  create_table "authorizations", :force => true do |t|
    t.string   "provider"
    t.string   "uid"
    t.integer  "user_id"
    t.integer  "account_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "business_calendars", :force => true do |t|
    t.integer  "account_id",         :limit => 8
    t.text     "business_time_data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "holiday_data"
    t.integer  "version",                         :default => 1
    t.string   "name"
    t.string   "description"
    t.string   "time_zone"
    t.boolean  "is_default",                      :default => false
  end

  add_index "business_calendars", ["account_id"], :name => "index_business_calendars_on_account_id"

  create_table "ca_folders", :force => true do |t|
    t.string   "name"
    t.boolean  "is_default",              :default => false
    t.integer  "account_id", :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "ca_folders", ["account_id"], :name => "Index_ca_folders_on_account_id"

  create_table "conversion_metrics", :force => true do |t|
    t.integer  "account_id",        :limit => 8
    t.string   "referrer"
    t.string   "landing_url"
    t.string   "first_referrer"
    t.string   "first_landing_url"
    t.string   "country"
    t.string   "language"
    t.string   "search_engine"
    t.string   "keywords"
    t.string   "device"
    t.string   "browser"
    t.string   "os"
    t.float    "offset"
    t.boolean  "is_dst"
    t.integer  "visits"
    t.text     "session_json"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "referrer_type"
  end

  create_table "customer_forums", :force => true do |t|
    t.integer  "customer_id", :limit => 8
    t.integer  "forum_id",    :limit => 8
    t.integer  "account_id",  :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "customer_forums", ["account_id", "customer_id"], :name => "index_customer_forum_on_account_id_and_customer_id"
  add_index "customer_forums", ["account_id", "forum_id"], :name => "index_customer_forum_on_account_id_and_forum_id"

  create_table "customers", :force => true do |t|
    t.string   "name"
    t.string   "cust_identifier"
    t.integer  "account_id",      :limit => 8
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "sla_policy_id",   :limit => 8
    t.text     "note"
    t.text     "domains"
    t.boolean  "delta",                        :default => true, :null => false
    t.integer  "import_id",       :limit => 8
  end

  add_index "customers", ["account_id", "name"], :name => "index_customers_on_account_id_and_name", :unique => true

  create_table "data_exports", :force => true do |t|
    t.integer  "account_id"
    t.boolean  "status"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "day_pass_configs", :force => true do |t|
    t.integer  "account_id",        :limit => 8
    t.integer  "available_passes"
    t.boolean  "auto_recharge"
    t.integer  "recharge_quantity"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "day_pass_purchases", :force => true do |t|
    t.integer  "account_id",         :limit => 8
    t.integer  "paid_with"
    t.string   "payment_type"
    t.integer  "payment_id",         :limit => 8
    t.integer  "status"
    t.integer  "quantity_purchased"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "status_message"
  end

  create_table "day_pass_usages", :force => true do |t|
    t.integer  "account_id", :limit => 8
    t.integer  "user_id",    :limit => 8
    t.text     "usage_info"
    t.datetime "granted_on"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0
    t.integer  "attempts",   :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["locked_by"], :name => "index_delayed_jobs_on_locked_by"

  create_table "deleted_customers", :force => true do |t|
    t.string   "full_domain"
    t.integer  "account_id"
    t.string   "admin_name"
    t.string   "admin_email"
    t.text     "account_info"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "status",       :default => 0
  end

  create_table "domain_mappings", :force => true do |t|
    t.integer "account_id", :limit => 8, :null => false
    t.integer "portal_id",  :limit => 8
    t.string  "domain",                  :null => false
  end

  add_index "domain_mappings", ["account_id", "portal_id"], :name => "index_domain_mappings_on_account_id_and_portal_id", :unique => true
  add_index "domain_mappings", ["domain"], :name => "index_domain_mappings_on_domain", :unique => true

  create_table "email_configs", :force => true do |t|
    t.integer  "account_id",      :limit => 8
    t.string   "to_email"
    t.string   "reply_email"
    t.integer  "group_id",        :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "primary_role",                 :default => false
    t.boolean  "active",                       :default => false
    t.string   "activator_token"
    t.string   "name"
    t.integer  "product_id",      :limit => 8
  end

  add_index "email_configs", ["account_id", "product_id"], :name => "index_email_configs_on_account_id_and_product_id"
  add_index "email_configs", ["account_id", "to_email"], :name => "index_email_configs_on_account_id_and_to_email", :unique => true

  create_table "email_notification_agents", :force => true do |t|
    t.integer  "email_notification_id", :limit => 8
    t.integer  "user_id",               :limit => 8
    t.integer  "account_id",            :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "email_notification_agents", ["account_id", "email_notification_id"], :name => "index_email_notification_agents_on_acc_and_email_notification_id"

  create_table "email_notifications", :force => true do |t|
    t.integer  "account_id",                 :limit => 8
    t.boolean  "requester_notification"
    t.text     "requester_template"
    t.boolean  "agent_notification"
    t.text     "agent_template"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "notification_type"
    t.text     "requester_subject_template"
    t.text     "agent_subject_template"
    t.integer  "version",                                 :default => 1
  end

  add_index "email_notifications", ["account_id", "notification_type"], :name => "index_email_notifications_on_notification_type", :unique => true

  create_table "es_enabled_accounts", :force => true do |t|
    t.integer  "account_id", :limit => 8
    t.boolean  "imported",                :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "es_enabled_accounts", ["account_id"], :name => "index_es_enabled_accounts_on_account_id"

  create_table "features", :force => true do |t|
    t.string   "type",                    :null => false
    t.integer  "account_id", :limit => 8, :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "features", ["account_id"], :name => "index_features_on_account_id"

  create_table "flexifield_def_entries", :force => true do |t|
    t.integer  "flexifield_def_id",  :limit => 8, :null => false
    t.string   "flexifield_name",                 :null => false
    t.string   "flexifield_alias",                :null => false
    t.string   "flexifield_tooltip"
    t.integer  "flexifield_order"
    t.string   "flexifield_coltype"
    t.string   "flexifield_defVal"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "import_id",          :limit => 8
    t.integer  "account_id",         :limit => 8
  end

  add_index "flexifield_def_entries", ["account_id", "flexifield_alias"], :name => "index_FFDef_entries_on_account_id_and_flexifield_alias"
  add_index "flexifield_def_entries", ["flexifield_def_id", "flexifield_name"], :name => "idx_ffde_onceperdef", :unique => true
  add_index "flexifield_def_entries", ["flexifield_def_id", "flexifield_order"], :name => "idx_ffde_ordering"

  create_table "flexifield_defs", :force => true do |t|
    t.string   "name",                    :null => false
    t.integer  "account_id", :limit => 8
    t.string   "module"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "flexifield_defs", ["name", "account_id"], :name => "idx_ffd_onceperdef", :unique => true

  create_table "flexifield_picklist_vals", :force => true do |t|
    t.integer  "flexifield_def_entry_id", :limit => 8, :null => false
    t.string   "value"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "position"
  end

  create_table "flexifields", :id => false, :force => true do |t|
    t.integer  "id",                  :limit => 8, :null => false
    t.integer  "flexifield_def_id",   :limit => 8
    t.integer  "flexifield_set_id",   :limit => 8
    t.string   "flexifield_set_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "ffs_01"
    t.string   "ffs_02"
    t.string   "ffs_03"
    t.string   "ffs_04"
    t.string   "ffs_05"
    t.string   "ffs_06"
    t.string   "ffs_07"
    t.string   "ffs_08"
    t.string   "ffs_09"
    t.string   "ffs_10"
    t.string   "ffs_11"
    t.string   "ffs_12"
    t.string   "ffs_13"
    t.string   "ffs_14"
    t.string   "ffs_15"
    t.string   "ffs_16"
    t.string   "ffs_17"
    t.string   "ffs_18"
    t.string   "ffs_19"
    t.string   "ffs_20"
    t.string   "ffs_21"
    t.string   "ffs_22"
    t.string   "ffs_23"
    t.string   "ffs_24"
    t.string   "ffs_25"
    t.string   "ffs_26"
    t.string   "ffs_27"
    t.string   "ffs_28"
    t.string   "ffs_29"
    t.string   "ffs_30"
    t.text     "ff_text01"
    t.text     "ff_text02"
    t.text     "ff_text03"
    t.text     "ff_text04"
    t.text     "ff_text05"
    t.text     "ff_text06"
    t.text     "ff_text07"
    t.text     "ff_text08"
    t.text     "ff_text09"
    t.text     "ff_text10"
    t.integer  "ff_int01"
    t.integer  "ff_int02"
    t.integer  "ff_int03"
    t.integer  "ff_int04"
    t.integer  "ff_int05"
    t.integer  "ff_int06"
    t.integer  "ff_int07"
    t.integer  "ff_int08"
    t.integer  "ff_int09"
    t.integer  "ff_int10"
    t.datetime "ff_date01"
    t.datetime "ff_date02"
    t.datetime "ff_date03"
    t.datetime "ff_date04"
    t.datetime "ff_date05"
    t.datetime "ff_date06"
    t.datetime "ff_date07"
    t.datetime "ff_date08"
    t.datetime "ff_date09"
    t.datetime "ff_date10"
    t.boolean  "ff_boolean01"
    t.boolean  "ff_boolean02"
    t.boolean  "ff_boolean03"
    t.boolean  "ff_boolean04"
    t.boolean  "ff_boolean05"
    t.boolean  "ff_boolean06"
    t.boolean  "ff_boolean07"
    t.boolean  "ff_boolean08"
    t.boolean  "ff_boolean09"
    t.boolean  "ff_boolean10"
    t.integer  "account_id",          :limit => 8
  end

  add_index "flexifields", ["account_id", "flexifield_set_id"], :name => "index_flexifields_on_flexifield_def_id_and_flexifield_set_id"
  add_index "flexifields", ["flexifield_def_id"], :name => "index_flexifields_on_flexifield_def_id"
  add_index "flexifields", ["id"], :name => "flexifields_id"

  create_table "forum_categories", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id",  :limit => 8
    t.integer  "import_id",   :limit => 8
    t.integer  "position"
  end

  add_index "forum_categories", ["account_id", "name"], :name => "index_forum_categories_on_account_id_and_name", :unique => true

  create_table "forums", :force => true do |t|
    t.string  "name"
    t.string  "description"
    t.integer "topics_count",                   :default => 0
    t.integer "posts_count",                    :default => 0
    t.integer "position"
    t.text    "description_html"
    t.integer "account_id",        :limit => 8
    t.integer "forum_category_id", :limit => 8
    t.integer "forum_type"
    t.integer "import_id",         :limit => 8
    t.integer "forum_visibility"
  end

  add_index "forums", ["forum_category_id", "name"], :name => "index_forums_on_forum_category_id", :unique => true

  create_table "google_accounts", :force => true do |t|
    t.string   "name"
    t.string   "email"
    t.string   "token"
    t.string   "secret"
    t.integer  "account_id",              :limit => 8
    t.string   "sync_group_id"
    t.string   "sync_group_name",                      :default => "Freshdesk Contacts",  :null => false
    t.integer  "sync_tag_id",             :limit => 8
    t.integer  "sync_type",                            :default => 0,                     :null => false
    t.datetime "last_sync_time",                       :default => '1970-01-01 00:00:00', :null => false
    t.string   "last_sync_status"
    t.boolean  "overwrite_existing_user",              :default => true,                  :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "google_contacts", :force => true do |t|
    t.integer "user_id",           :limit => 8
    t.string  "google_id"
    t.text    "google_xml"
    t.integer "google_account_id", :limit => 8
    t.integer "account_id",        :limit => 8
  end

  create_table "groups", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "account_id",           :limit => 8
    t.boolean  "email_on_assign"
    t.integer  "escalate_to",          :limit => 8
    t.integer  "assign_time"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "import_id",            :limit => 8
    t.integer  "ticket_assign_type",                :default => 0
    t.integer  "business_calendar_id"
  end

  add_index "groups", ["account_id", "name"], :name => "index_groups_on_account_id", :unique => true

  create_table "helpdesk_activities", :id => false, :force => true do |t|
    t.integer  "id",            :limit => 8, :null => false
    t.integer  "account_id",    :limit => 8
    t.text     "description"
    t.integer  "notable_id",    :limit => 8
    t.string   "notable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id",       :limit => 8
    t.text     "activity_data"
    t.text     "short_descr"
  end

  add_index "helpdesk_activities", ["account_id", "notable_type", "notable_id"], :name => "index_helpdesk_activities_on_notables"
  add_index "helpdesk_activities", ["id"], :name => "helpdesk_activities_id"

  create_table "helpdesk_attachments", :id => false, :force => true do |t|
    t.integer  "id",                   :limit => 8, :null => false
    t.text     "description"
    t.string   "content_file_name"
    t.string   "content_content_type"
    t.integer  "content_file_size"
    t.integer  "content_updated_at"
    t.integer  "attachable_id",        :limit => 8
    t.string   "attachable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id",           :limit => 8
  end

  add_index "helpdesk_attachments", ["account_id", "attachable_id", "attachable_type"], :name => "index_helpdesk_attachments_on_attachable_id", :length => {"attachable_type"=>"14", "attachable_id"=>nil, "account_id"=>nil}
  add_index "helpdesk_attachments", ["id"], :name => "helpdesk_attachments_id"

  create_table "helpdesk_authorizations", :force => true do |t|
    t.string   "role_token"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "helpdesk_authorizations", ["role_token"], :name => "index_helpdesk_authorizations_on_role_token"
  add_index "helpdesk_authorizations", ["user_id"], :name => "index_helpdesk_authorizations_on_user_id"

  create_table "helpdesk_dropboxes", :id => false, :force => true do |t|
    t.integer  "id",             :limit => 8, :null => false
    t.text     "url"
    t.integer  "account_id",     :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "droppable_id"
    t.string   "droppable_type"
  end

  add_index "helpdesk_dropboxes", ["account_id", "droppable_id", "droppable_type"], :name => "index_helpdesk_dropboxes_on_droppable_id"
  add_index "helpdesk_dropboxes", ["id"], :name => "helpdesk_dropboxes_id"

  create_table "helpdesk_external_notes", :id => false, :force => true do |t|
    t.integer "id",                       :limit => 8, :null => false
    t.integer "account_id",               :limit => 8
    t.integer "note_id",                  :limit => 8
    t.integer "installed_application_id", :limit => 8
    t.string  "external_id"
  end

  add_index "helpdesk_external_notes", ["account_id", "installed_application_id", "external_id"], :name => "index_helpdesk_external_id", :length => {"external_id"=>"20", "installed_application_id"=>nil, "account_id"=>nil}
  add_index "helpdesk_external_notes", ["id"], :name => "helpdesk_external_notes_id"

  create_table "helpdesk_issues", :force => true do |t|
    t.string   "title"
    t.text     "description"
    t.integer  "user_id"
    t.integer  "owner_id"
    t.integer  "status",              :default => 1
    t.boolean  "deleted",             :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "ticket_issues_count"
  end

  create_table "helpdesk_nested_ticket_fields", :force => true do |t|
    t.integer  "account_id",              :limit => 8
    t.integer  "ticket_field_id",         :limit => 8
    t.string   "name"
    t.string   "label"
    t.string   "label_in_portal"
    t.string   "description"
    t.integer  "flexifield_def_entry_id", :limit => 8
    t.integer  "level"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "helpdesk_nested_ticket_fields", ["account_id", "name"], :name => "index_helpdesk_nested_ticket_fields_on_account_id_and_name", :unique => true

  create_table "helpdesk_note_bodies", :id => false, :force => true do |t|
    t.integer  "id",             :limit => 8,        :null => false
    t.integer  "note_id",        :limit => 8
    t.text     "body",           :limit => 16777215
    t.text     "body_html",      :limit => 16777215
    t.text     "full_text",      :limit => 16777215
    t.text     "full_text_html", :limit => 16777215
    t.integer  "account_id",     :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "raw_text",       :limit => 16777215
    t.text     "raw_html",       :limit => 16777215
    t.text     "meta_info",      :limit => 16777215
    t.integer  "version"
  end

  add_index "helpdesk_note_bodies", ["account_id", "note_id"], :name => "index_note_bodies_on_account_id_and_note_id", :unique => true
  add_index "helpdesk_note_bodies", ["id"], :name => "index_helpdesk_note_bodies_id"

  create_table "helpdesk_notes", :id => false, :force => true do |t|
    t.integer  "id",           :limit => 8,                             :null => false
    t.text     "body",         :limit => 2147483647
    t.integer  "user_id",      :limit => 8
    t.integer  "source",                             :default => 0
    t.boolean  "incoming",                           :default => false
    t.boolean  "private",                            :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "deleted",                            :default => false
    t.integer  "notable_id",   :limit => 8
    t.string   "notable_type"
    t.integer  "account_id",   :limit => 8
    t.text     "body_html",    :limit => 2147483647
  end

  add_index "helpdesk_notes", ["account_id", "notable_type", "notable_id"], :name => "index_helpdesk_notes_on_notables"
  add_index "helpdesk_notes", ["id"], :name => "helpdesk_notes_id"

  create_table "helpdesk_picklist_values", :force => true do |t|
    t.integer  "pickable_id",   :limit => 8
    t.string   "pickable_type"
    t.integer  "position"
    t.string   "value"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id",    :limit => 8
  end

  add_index "helpdesk_picklist_values", ["account_id", "pickable_type", "pickable_id"], :name => "index_on_picklist_account_id_and_pickabke_type_and_pickable_id"

  create_table "helpdesk_reminders", :force => true do |t|
    t.string   "body"
    t.boolean  "deleted",                 :default => false
    t.integer  "user_id",    :limit => 8
    t.integer  "ticket_id",  :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id", :limit => 8
  end

  add_index "helpdesk_reminders", ["ticket_id"], :name => "index_helpdesk_reminders_on_ticket_id"
  add_index "helpdesk_reminders", ["user_id"], :name => "index_helpdesk_reminders_on_user_id"

  create_table "helpdesk_schema_less_notes", :id => false, :force => true do |t|
    t.integer  "id",            :limit => 8,                    :null => false
    t.integer  "note_id",       :limit => 8
    t.integer  "account_id",    :limit => 8
    t.string   "from_email"
    t.text     "to_emails"
    t.text     "cc_emails"
    t.text     "bcc_emails"
    t.integer  "long_nc01",     :limit => 8
    t.integer  "long_nc02",     :limit => 8
    t.integer  "long_nc03",     :limit => 8
    t.integer  "long_nc04",     :limit => 8
    t.integer  "long_nc05",     :limit => 8
    t.integer  "long_nc06",     :limit => 8
    t.integer  "long_nc07",     :limit => 8
    t.integer  "long_nc08",     :limit => 8
    t.integer  "long_nc09",     :limit => 8
    t.integer  "long_nc10",     :limit => 8
    t.integer  "int_nc01"
    t.integer  "int_nc02"
    t.integer  "int_nc03"
    t.integer  "int_nc04"
    t.integer  "int_nc05"
    t.string   "string_nc01"
    t.string   "string_nc02"
    t.string   "string_nc03"
    t.string   "string_nc04"
    t.string   "string_nc05"
    t.string   "string_nc06"
    t.string   "string_nc07"
    t.string   "string_nc08"
    t.string   "string_nc09"
    t.string   "string_nc10"
    t.string   "string_nc11"
    t.string   "string_nc12"
    t.string   "string_nc13"
    t.string   "string_nc14"
    t.string   "string_nc15"
    t.datetime "datetime_nc01"
    t.datetime "datetime_nc02"
    t.datetime "datetime_nc03"
    t.datetime "datetime_nc04"
    t.datetime "datetime_nc05"
    t.boolean  "boolean_nc01",               :default => false
    t.boolean  "boolean_nc02",               :default => false
    t.boolean  "boolean_nc03",               :default => false
    t.boolean  "boolean_nc04",               :default => false
    t.boolean  "boolean_nc05",               :default => false
    t.text     "text_nc01"
    t.text     "text_nc02"
    t.text     "text_nc03"
    t.text     "text_nc04"
    t.text     "text_nc05"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "helpdesk_schema_less_notes", ["account_id", "note_id"], :name => "index_helpdesk_schema_less_notes_on_account_id_note_id", :unique => true
  add_index "helpdesk_schema_less_notes", ["account_id", "string_nc01"], :name => "index_helpdesk_schema_less_notes_on_account_id_string_nc01", :length => {"string_nc01"=>"10", "account_id"=>nil}
  add_index "helpdesk_schema_less_notes", ["account_id", "string_nc02"], :name => "index_helpdesk_schema_less_notes_on_account_id_string_nc02", :length => {"string_nc02"=>"10", "account_id"=>nil}
  add_index "helpdesk_schema_less_notes", ["id"], :name => "helpdesk_schema_less_notes_id"
  add_index "helpdesk_schema_less_notes", ["int_nc01", "account_id"], :name => "index_helpdesk_schema_less_notes_on_int_nc01_account_id"
  add_index "helpdesk_schema_less_notes", ["int_nc02", "account_id"], :name => "index_helpdesk_schema_less_notes_on_int_nc02_account_id"
  add_index "helpdesk_schema_less_notes", ["long_nc01", "account_id"], :name => "index_helpdesk_schema_less_notes_on_long_nc01_account_id"
  add_index "helpdesk_schema_less_notes", ["long_nc02", "account_id"], :name => "index_helpdesk_schema_less_notes_on_long_nc02_account_id"

  create_table "helpdesk_schema_less_tickets", :id => false, :force => true do |t|
    t.integer  "id",            :limit => 8,                    :null => false
    t.integer  "account_id",    :limit => 8
    t.integer  "ticket_id",     :limit => 8
    t.integer  "product_id",    :limit => 8
    t.text     "to_emails"
    t.integer  "long_tc01",     :limit => 8
    t.integer  "long_tc02",     :limit => 8
    t.integer  "long_tc03",     :limit => 8
    t.integer  "long_tc04",     :limit => 8
    t.integer  "long_tc05",     :limit => 8
    t.integer  "long_tc06",     :limit => 8
    t.integer  "long_tc07",     :limit => 8
    t.integer  "long_tc08",     :limit => 8
    t.integer  "long_tc09",     :limit => 8
    t.integer  "long_tc10",     :limit => 8
    t.integer  "int_tc01"
    t.integer  "int_tc02"
    t.integer  "int_tc03"
    t.integer  "int_tc04"
    t.integer  "int_tc05"
    t.string   "string_tc01"
    t.string   "string_tc02"
    t.string   "string_tc03"
    t.string   "string_tc04"
    t.string   "string_tc05"
    t.string   "string_tc06"
    t.string   "string_tc07"
    t.string   "string_tc08"
    t.string   "string_tc09"
    t.string   "string_tc10"
    t.string   "string_tc11"
    t.string   "string_tc12"
    t.string   "string_tc13"
    t.string   "string_tc14"
    t.string   "string_tc15"
    t.datetime "datetime_tc01"
    t.datetime "datetime_tc02"
    t.datetime "datetime_tc03"
    t.datetime "datetime_tc04"
    t.datetime "datetime_tc05"
    t.boolean  "boolean_tc01",               :default => false
    t.boolean  "boolean_tc02",               :default => false
    t.boolean  "boolean_tc03",               :default => false
    t.boolean  "boolean_tc04",               :default => false
    t.boolean  "boolean_tc05",               :default => false
    t.text     "text_tc01"
    t.text     "text_tc02"
    t.text     "text_tc03"
    t.text     "text_tc04"
    t.text     "text_tc05"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "helpdesk_schema_less_tickets", ["account_id", "product_id"], :name => "index_helpdesk_schema_less_tickets_on_ticket_id_and_product_id"
  add_index "helpdesk_schema_less_tickets", ["id"], :name => "helpdesk_schema_less_tickets_id"
  add_index "helpdesk_schema_less_tickets", ["int_tc01", "account_id"], :name => "index_helpdesk_schema_less_tickets_on_ticket_id_and_int_01"
  add_index "helpdesk_schema_less_tickets", ["int_tc02", "account_id"], :name => "index_helpdesk_schema_less_tickets_on_ticket_id_and_int_02"
  add_index "helpdesk_schema_less_tickets", ["long_tc01", "account_id"], :name => "index_helpdesk_schema_less_tickets_on_ticket_id_and_long_01"
  add_index "helpdesk_schema_less_tickets", ["long_tc02", "account_id"], :name => "index_helpdesk_schema_less_tickets_on_ticket_id_and_long_02"
  add_index "helpdesk_schema_less_tickets", ["string_tc01", "account_id"], :name => "index_helpdesk_schema_less_tickets_on_ticket_id_and_string_01", :length => {"account_id"=>nil, "string_tc01"=>"10"}
  add_index "helpdesk_schema_less_tickets", ["string_tc02", "account_id"], :name => "index_helpdesk_schema_less_tickets_on_ticket_id_and_string_02", :length => {"account_id"=>nil, "string_tc02"=>"10"}
  add_index "helpdesk_schema_less_tickets", ["ticket_id", "account_id"], :name => "index_helpdesk_schema_less_tickets_on_account_id_ticket_id", :unique => true

  create_table "helpdesk_shared_attachments", :force => true do |t|
    t.string   "shared_attachable_type"
    t.integer  "shared_attachable_id",   :limit => 8
    t.integer  "attachment_id",          :limit => 8
    t.integer  "account_id",             :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "helpdesk_subscriptions", :force => true do |t|
    t.integer  "user_id",    :limit => 8
    t.integer  "ticket_id",  :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id", :limit => 8
  end

  add_index "helpdesk_subscriptions", ["ticket_id"], :name => "index_helpdesk_subscriptions_on_ticket_id"
  add_index "helpdesk_subscriptions", ["user_id"], :name => "index_helpdesk_subscriptions_on_user_id"

  create_table "helpdesk_tag_uses", :force => true do |t|
    t.integer "tag_id",        :limit => 8, :null => false
    t.string  "taggable_type"
    t.integer "taggable_id",   :limit => 8
    t.integer "account_id",    :limit => 8
  end

  add_index "helpdesk_tag_uses", ["tag_id"], :name => "index_helpdesk_tag_uses_on_tag_id"
  add_index "helpdesk_tag_uses", ["taggable_id", "taggable_type"], :name => "helpdesk_tag_uses_taggable", :length => {"taggable_id"=>nil, "taggable_type"=>"10"}

  create_table "helpdesk_tags", :force => true do |t|
    t.string  "name"
    t.integer "tag_uses_count"
    t.integer "account_id",     :limit => 8
  end

  add_index "helpdesk_tags", ["account_id", "name"], :name => "index_helpdesk_tags_on_account_id_and_name", :unique => true

  create_table "helpdesk_ticket_bodies", :id => false, :force => true do |t|
    t.integer  "id",               :limit => 8,        :null => false
    t.integer  "ticket_id",        :limit => 8
    t.text     "description",      :limit => 16777215
    t.text     "description_html", :limit => 16777215
    t.integer  "account_id",       :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "raw_text",         :limit => 16777215
    t.text     "raw_html",         :limit => 16777215
    t.text     "meta_info",        :limit => 16777215
    t.integer  "version"
  end

  add_index "helpdesk_ticket_bodies", ["account_id", "ticket_id"], :name => "index_ticket_bodies_on_account_id_and_ticket_id", :unique => true
  add_index "helpdesk_ticket_bodies", ["id"], :name => "index_helpdesk_ticket_bodies_id"

  create_table "helpdesk_ticket_fields", :force => true do |t|
    t.integer  "account_id",              :limit => 8
    t.string   "name"
    t.string   "label"
    t.string   "label_in_portal"
    t.text     "description"
    t.boolean  "active",                               :default => true
    t.string   "field_type"
    t.integer  "position"
    t.boolean  "required",                             :default => false
    t.boolean  "visible_in_portal",                    :default => false
    t.boolean  "editable_in_portal",                   :default => false
    t.boolean  "required_in_portal",                   :default => false
    t.boolean  "required_for_closure",                 :default => false
    t.integer  "flexifield_def_entry_id", :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "field_options"
  end

  add_index "helpdesk_ticket_fields", ["account_id", "field_type", "position"], :name => "index_tkt_flds_on_account_id_and_field_type_and_position"
  add_index "helpdesk_ticket_fields", ["account_id", "name"], :name => "index_helpdesk_ticket_fields_on_account_id_and_name", :unique => true

  create_table "helpdesk_ticket_issues", :force => true do |t|
    t.integer "ticket_id"
    t.integer "issue_id"
  end

  add_index "helpdesk_ticket_issues", ["issue_id"], :name => "index_helpdesk_ticket_issues_on_issue_id"
  add_index "helpdesk_ticket_issues", ["ticket_id"], :name => "index_helpdesk_ticket_issues_on_ticket_id"

  create_table "helpdesk_ticket_states", :id => false, :force => true do |t|
    t.integer  "id",                        :limit => 8,                    :null => false
    t.integer  "ticket_id",                 :limit => 8
    t.datetime "opened_at"
    t.datetime "pending_since"
    t.datetime "resolved_at"
    t.datetime "closed_at"
    t.datetime "first_assigned_at"
    t.datetime "assigned_at"
    t.datetime "first_response_time"
    t.datetime "requester_responded_at"
    t.datetime "agent_responded_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "group_escalated",                        :default => false
    t.integer  "inbound_count",                          :default => 1
    t.integer  "account_id",                :limit => 8
    t.datetime "status_updated_at"
    t.datetime "sla_timer_stopped_at"
    t.integer  "outbound_count",                         :default => 0
    t.float    "avg_response_time"
    t.integer  "first_resp_time_by_bhrs"
    t.integer  "resolution_time_by_bhrs"
    t.float    "avg_response_time_by_bhrs"
  end

  add_index "helpdesk_ticket_states", ["account_id", "ticket_id"], :name => "index_helpdesk_ticket_states_on_account_and_ticket", :unique => true
  add_index "helpdesk_ticket_states", ["id"], :name => "helpdesk_ticket_states_id"

  create_table "helpdesk_ticket_statuses", :force => true do |t|
    t.integer  "status_id",             :limit => 8
    t.string   "name"
    t.string   "customer_display_name"
    t.boolean  "stop_sla_timer",                     :default => false
    t.boolean  "deleted",                            :default => false
    t.boolean  "is_default",                         :default => false
    t.integer  "account_id",            :limit => 8
    t.integer  "ticket_field_id",       :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "position"
  end

  add_index "helpdesk_ticket_statuses", ["account_id"], :name => "index_helpdesk_ticket_statuses_on_account_id"
  add_index "helpdesk_ticket_statuses", ["ticket_field_id", "status_id"], :name => "index_helpdesk_ticket_statuses_on_ticket_field_id_and_status_id", :unique => true

  create_table "helpdesk_tickets", :id => false, :force => true do |t|
    t.integer  "id",               :limit => 8,                             :null => false
    t.text     "description",      :limit => 2147483647
    t.integer  "requester_id",     :limit => 8
    t.integer  "responder_id",     :limit => 8
    t.integer  "status",           :limit => 8,          :default => 1
    t.boolean  "urgent",                                 :default => false
    t.integer  "source",                                 :default => 0
    t.boolean  "spam",                                   :default => false
    t.boolean  "deleted",                                :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "trained",                                :default => false
    t.integer  "account_id",       :limit => 8
    t.string   "subject"
    t.integer  "display_id",       :limit => 8
    t.integer  "owner_id",         :limit => 8
    t.integer  "group_id",         :limit => 8
    t.datetime "due_by"
    t.datetime "frDueBy"
    t.boolean  "isescalated",                            :default => false
    t.integer  "priority",         :limit => 8,          :default => 1
    t.boolean  "fr_escalated",                           :default => false
    t.string   "to_email"
    t.integer  "email_config_id",  :limit => 8
    t.text     "cc_email"
    t.boolean  "delta",                                  :default => true,  :null => false
    t.integer  "import_id",        :limit => 8
    t.string   "ticket_type"
    t.text     "description_html", :limit => 2147483647
  end

  add_index "helpdesk_tickets", ["account_id", "created_at", "id"], :name => "index_helpdesk_tickets_on_account_id_and_created_at_and_id"
  add_index "helpdesk_tickets", ["account_id", "display_id"], :name => "index_helpdesk_tickets_on_account_id_and_display_id", :unique => true
  add_index "helpdesk_tickets", ["account_id", "due_by", "id"], :name => "index_helpdesk_tickets_on_account_id_and_due_by_and_id"
  add_index "helpdesk_tickets", ["account_id", "import_id"], :name => "index_helpdesk_tickets_on_account_id_and_import_id", :unique => true
  add_index "helpdesk_tickets", ["account_id", "updated_at", "id"], :name => "index_helpdesk_tickets_on_account_id_and_updated_at_and_id"
  add_index "helpdesk_tickets", ["id"], :name => "helpdesk_tickets_id"
  add_index "helpdesk_tickets", ["requester_id", "account_id"], :name => "index_helpdesk_tickets_on_requester_id_and_account_id"
  add_index "helpdesk_tickets", ["responder_id", "account_id"], :name => "index_helpdesk_tickets_on_responder_id_and_account_id"

  create_table "helpdesk_time_sheets", :force => true do |t|
    t.datetime "start_time"
    t.integer  "time_spent",    :limit => 8
    t.boolean  "timer_running",              :default => false
    t.boolean  "billable",                   :default => true
    t.integer  "user_id",       :limit => 8
    t.text     "note"
    t.integer  "account_id",    :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "executed_at"
    t.integer  "workable_id",   :limit => 8
    t.string   "workable_type",              :default => "Helpdesk::Ticket"
  end

  add_index "helpdesk_time_sheets", ["account_id", "workable_type", "workable_id"], :name => "index_helpdesk_sheets_on_workable_account"
  add_index "helpdesk_time_sheets", ["user_id"], :name => "index_time_sheets_on_user_id"

  create_table "installed_applications", :force => true do |t|
    t.integer  "application_id"
    t.integer  "account_id",     :limit => 8
    t.text     "configs"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "installed_applications", ["account_id"], :name => "index_account_id_on_installed_applications"

  create_table "integrated_resources", :force => true do |t|
    t.integer  "installed_application_id", :limit => 8
    t.string   "remote_integratable_id"
    t.integer  "local_integratable_id",    :limit => 8
    t.string   "local_integratable_type"
    t.integer  "account_id",               :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "integrations_user_credentials", :force => true do |t|
    t.integer  "installed_application_id", :limit => 8
    t.integer  "user_id",                  :limit => 8
    t.text     "auth_info"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id",               :limit => 8
  end

  create_table "key_value_pairs", :force => true do |t|
    t.string  "key"
    t.text    "value"
    t.string  "obj_type"
    t.integer "account_id", :limit => 8
  end

  create_table "moderatorships", :force => true do |t|
    t.integer "forum_id", :limit => 8
    t.integer "user_id",  :limit => 8
  end

  add_index "moderatorships", ["forum_id"], :name => "index_moderatorships_on_forum_id"

  create_table "monitorships", :force => true do |t|
    t.integer "topic_id",   :limit => 8
    t.integer "user_id",    :limit => 8
    t.boolean "active",                  :default => true
    t.integer "account_id", :limit => 8
  end

  add_index "monitorships", ["user_id", "account_id"], :name => "index_for_monitorships_on_user_id_account_id"

  create_table "password_resets", :force => true do |t|
    t.string   "email"
    t.integer  "user_id",    :limit => 8
    t.string   "remote_ip"
    t.string   "token"
    t.datetime "created_at"
  end

  create_table "portal_pages", :force => true do |t|
    t.integer  "template_id", :limit => 8,        :null => false
    t.integer  "account_id",  :limit => 8,        :null => false
    t.integer  "page_type",                       :null => false
    t.text     "content",     :limit => 16777215
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "portal_templates", :force => true do |t|
    t.integer  "account_id",  :limit => 8,        :null => false
    t.integer  "portal_id",   :limit => 8,        :null => false
    t.text     "preferences"
    t.text     "header"
    t.text     "footer"
    t.text     "custom_css",  :limit => 16777215
    t.text     "layout"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "portals", :force => true do |t|
    t.string   "name"
    t.integer  "product_id",           :limit => 8
    t.integer  "account_id",           :limit => 8
    t.string   "portal_url"
    t.text     "preferences"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "solution_category_id", :limit => 8
    t.integer  "forum_category_id",    :limit => 8
    t.string   "language",                          :default => "en"
    t.boolean  "main_portal",                       :default => false
    t.boolean  "ssl_enabled",                       :default => false
    t.string   "elb_dns_name"
  end

  add_index "portals", ["account_id", "portal_url"], :name => "index_portals_on_account_id_and_portal_url"
  add_index "portals", ["account_id", "product_id"], :name => "index_portals_on_account_id_and_product_id"
  add_index "portals", ["portal_url"], :name => "index_portals_on_portal_url"

  create_table "posts", :force => true do |t|
    t.integer  "user_id",    :limit => 8
    t.integer  "topic_id",   :limit => 8
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "forum_id",   :limit => 8
    t.text     "body_html"
    t.integer  "account_id", :limit => 8
    t.boolean  "answer",                  :default => false
    t.integer  "import_id",  :limit => 8
  end

  add_index "posts", ["account_id", "created_at"], :name => "index_posts_on_account_id_and_created_at"
  add_index "posts", ["forum_id", "created_at"], :name => "index_posts_on_forum_id"
  add_index "posts", ["topic_id", "created_at"], :name => "index_posts_on_topic_id"
  add_index "posts", ["user_id", "created_at"], :name => "index_posts_on_user_id"

  create_table "products", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "account_id",  :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "products", ["account_id", "name"], :name => "index_products_on_account_id_and_name"

  create_table "quests", :force => true do |t|
    t.integer  "account_id",   :limit => 8
    t.string   "name"
    t.text     "description"
    t.integer  "sub_category"
    t.integer  "category"
    t.boolean  "active",                    :default => true
    t.text     "filter_data"
    t.text     "quest_data"
    t.integer  "points",                    :default => 0
    t.integer  "badge_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "quests", ["account_id", "category"], :name => "index_quests_on_account_id_and_category"

  create_table "report_filters", :force => true do |t|
    t.integer  "report_type"
    t.string   "filter_name"
    t.text     "data_hash"
    t.integer  "user_id",     :limit => 8
    t.integer  "account_id",  :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "report_filters", ["account_id", "report_type"], :name => "index_report_filters_account_id_and_report_type"

  
  create_table "roles", :force => true do |t|
    t.string   "name"
    t.string   "privileges"
    t.text     "description"
    t.boolean  "default_role",              :default => false
    t.integer  "account_id",   :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "roles", ["account_id", "name"], :name => "index_roles_on_account_id_and_name", :unique => true

  create_table "scoreboard_levels", :force => true do |t|
    t.integer  "account_id", :limit => 8
    t.integer  "points"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "scoreboard_levels", ["account_id"], :name => "index_scoreboard_levels_on_account_id"

  create_table "scoreboard_ratings", :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.integer  "resolution_speed"
    t.integer  "score"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "shard_mappings", :primary_key => "account_id", :force => true do |t|
    t.string  "shard_name",                  :null => false
    t.integer "status",     :default => 200, :null => false
  end

  create_table "sla_details", :force => true do |t|
    t.string   "name"
    t.integer  "priority",           :limit => 8
    t.integer  "response_time"
    t.integer  "resolution_time"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "sla_policy_id",      :limit => 8
    t.boolean  "override_bhrs",                   :default => false
    t.integer  "account_id",         :limit => 8
    t.boolean  "escalation_enabled",              :default => true
  end

  add_index "sla_details", ["account_id", "sla_policy_id"], :name => "index_account_id_and_sla_policy_id_on_sla_details"

  create_table "sla_policies", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "account_id",  :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "is_default",               :default => false
    t.text     "escalations"
    t.text     "conditions"
    t.integer  "position"
    t.boolean  "active",                   :default => true
  end

  add_index "sla_policies", ["account_id", "name"], :name => "index_helpdesk_sla_policies_on_account_id_and_name", :unique => true

  create_table "social_facebook_pages", :force => true do |t|
    t.integer  "profile_id",           :limit => 8
    t.string   "access_token"
    t.integer  "page_id",              :limit => 8
    t.string   "page_name"
    t.string   "page_token"
    t.string   "page_img_url"
    t.string   "page_link"
    t.boolean  "import_visitor_posts",              :default => true
    t.boolean  "import_company_posts",              :default => false
    t.boolean  "enable_page",                       :default => false
    t.integer  "fetch_since",          :limit => 8
    t.integer  "product_id",           :limit => 8
    t.integer  "account_id",           :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "dm_thread_time",       :limit => 8, :default => 99999999999999999
    t.integer  "message_since",        :limit => 8, :default => 0
    t.boolean  "import_dms",                        :default => true
    t.boolean  "reauth_required",                   :default => false
    t.text     "last_error"
  end

  add_index "social_facebook_pages", ["account_id", "page_id"], :name => "index_account_page_id", :unique => true
  add_index "social_facebook_pages", ["product_id"], :name => "index_product_id"

  create_table "social_fb_posts", :force => true do |t|
    t.string   "post_id"
    t.integer  "postable_id",      :limit => 8
    t.string   "postable_type"
    t.integer  "facebook_page_id", :limit => 8
    t.integer  "account_id",       :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "msg_type",                      :default => "post"
    t.string   "thread_id"
  end

  add_index "social_fb_posts", ["account_id", "postable_id", "postable_type"], :name => "index_social_fb_posts_account_id_postable_id_postable_type", :length => {"postable_type"=>"15", "postable_id"=>nil, "account_id"=>nil}

  create_table "social_tweets", :force => true do |t|
    t.integer  "tweet_id",          :limit => 8
    t.integer  "tweetable_id",      :limit => 8
    t.string   "tweetable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id"
    t.string   "tweet_type",                     :default => "mention"
    t.integer  "twitter_handle_id", :limit => 8
  end

  add_index "social_tweets", ["account_id", "tweetable_id", "tweetable_type"], :name => "index_social_tweets_account_id_tweetable_id_tweetable_type", :length => {"tweetable_type"=>"15", "tweetable_id"=>nil, "account_id"=>nil}

  create_table "social_twitter_handles", :force => true do |t|
    t.integer  "twitter_user_id",           :limit => 8
    t.string   "screen_name"
    t.string   "access_token"
    t.string   "access_secret"
    t.boolean  "capture_dm_as_ticket",                   :default => false
    t.boolean  "capture_mention_as_ticket",              :default => false
    t.integer  "product_id",                :limit => 8
    t.integer  "last_dm_id",                :limit => 8
    t.integer  "last_mention_id",           :limit => 8
    t.integer  "account_id"
    t.text     "search_keys"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "dm_thread_time",                         :default => 0
    t.integer  "state"
    t.text     "last_error"
  end

  add_index "social_twitter_handles", ["account_id", "twitter_user_id"], :name => "social_twitter_handle_product_id", :unique => true

  create_table "solution_articles", :force => true do |t|
    t.string   "title"
    t.text     "description",  :limit => 2147483647
    t.integer  "user_id",      :limit => 8
    t.integer  "folder_id",    :limit => 8
    t.integer  "status"
    t.integer  "art_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "thumbs_up",                          :default => 0
    t.integer  "thumbs_down",                        :default => 0
    t.integer  "account_id",   :limit => 8
    t.boolean  "delta",                              :default => true, :null => false
    t.text     "desc_un_html", :limit => 2147483647
    t.integer  "import_id",    :limit => 8
    t.integer  "position"
    t.text     "seo_data"
  end

  add_index "solution_articles", ["account_id", "folder_id"], :name => "index_solution_articles_on_account_id"
  add_index "solution_articles", ["folder_id"], :name => "index_solution_articles_on_folder_id"

  create_table "solution_categories", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "account_id",  :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "import_id",   :limit => 8
    t.integer  "position"
    t.boolean  "is_default",               :default => false
  end

  add_index "solution_categories", ["account_id", "name"], :name => "index_solution_categories_on_account_id_and_name", :unique => true

  create_table "solution_customer_folders", :force => true do |t|
    t.integer  "customer_id", :limit => 8
    t.integer  "folder_id",   :limit => 8
    t.integer  "account_id",  :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "solution_customer_folders", ["account_id", "customer_id"], :name => "index_customer_folder_on_account_id_and_customer_id"
  add_index "solution_customer_folders", ["account_id", "folder_id"], :name => "index_customer_folder_on_account_id_and_folder_id"

  create_table "solution_folders", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "category_id", :limit => 8
    t.integer  "import_id",   :limit => 8
    t.integer  "visibility",  :limit => 8
    t.integer  "position"
    t.boolean  "is_default",               :default => false
    t.integer  "account_id",  :limit => 8
  end

  add_index "solution_folders", ["category_id", "name"], :name => "index_solution_folders_on_category_id_and_name", :unique => true

  create_table "subscription_affiliates", :force => true do |t|
    t.string   "name"
    t.decimal  "rate",       :precision => 6, :scale => 4, :default => 0.0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "token"
  end

  add_index "subscription_affiliates", ["token"], :name => "index_subscription_affiliates_on_token"

  create_table "subscription_announcements", :force => true do |t|
    t.text     "message"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "subscription_discounts", :force => true do |t|
    t.string   "name"
    t.string   "code"
    t.decimal  "amount",                              :precision => 6, :scale => 2, :default => 0.0
    t.boolean  "percent"
    t.date     "start_on"
    t.date     "end_on"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "apply_to_setup",                                                    :default => true
    t.boolean  "apply_to_recurring",                                                :default => true
    t.integer  "trial_period_extension",                                            :default => 0
    t.integer  "plan_id",                :limit => 8
    t.integer  "life_time"
    t.integer  "free_agents"
  end

  create_table "subscription_events", :force => true do |t|
    t.integer  "account_id",                :limit => 8
    t.integer  "code"
    t.text     "info"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "subscription_plan_id"
    t.integer  "renewal_period"
    t.integer  "total_agents"
    t.integer  "free_agents"
    t.integer  "subscription_affiliate_id"
    t.integer  "subscription_discount_id"
    t.boolean  "revenue_type"
    t.decimal  "cmrr",                                   :precision => 10, :scale => 2
  end

  create_table "subscription_payments", :force => true do |t|
    t.integer  "account_id",                :limit => 8
    t.integer  "subscription_id",           :limit => 8
    t.decimal  "amount",                                 :precision => 10, :scale => 2, :default => 0.0
    t.string   "transaction_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "setup"
    t.boolean  "misc"
    t.integer  "subscription_affiliate_id", :limit => 8
    t.decimal  "affiliate_amount",                       :precision => 6,  :scale => 2, :default => 0.0
    t.text     "meta_info"
  end

  add_index "subscription_payments", ["account_id"], :name => "index_subscription_payments_on_account_id"
  add_index "subscription_payments", ["subscription_id"], :name => "index_subscription_payments_on_subscription_id"

  create_table "subscription_plans", :force => true do |t|
    t.string   "name"
    t.decimal  "amount",          :precision => 10, :scale => 2
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "renewal_period",                                 :default => 1
    t.decimal  "setup_amount",    :precision => 10, :scale => 2
    t.integer  "trial_period",                                   :default => 1
    t.integer  "free_agents"
    t.decimal  "day_pass_amount", :precision => 10, :scale => 2
    t.boolean  "classic",                                        :default => false
  end

  create_table "subscriptions", :force => true do |t|
    t.decimal  "amount",                                 :precision => 10, :scale => 2
    t.datetime "next_renewal_at"
    t.string   "card_number"
    t.string   "card_expiration"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "state",                                                                 :default => "trial"
    t.integer  "subscription_plan_id",      :limit => 8
    t.integer  "account_id",                :limit => 8
    t.integer  "renewal_period",                                                        :default => 1
    t.string   "billing_id"
    t.integer  "subscription_discount_id",  :limit => 8
    t.integer  "subscription_affiliate_id", :limit => 8
    t.integer  "agent_limit"
    t.integer  "free_agents"
    t.decimal  "day_pass_amount",                        :precision => 10, :scale => 2
    t.datetime "discount_expires_at"
  end

  add_index "subscriptions", ["account_id"], :name => "index_subscriptions_on_account_id"

  create_table "support_scores", :id => false, :force => true do |t|
    t.integer  "id",            :limit => 8, :null => false
    t.integer  "account_id",    :limit => 8
    t.integer  "user_id",       :limit => 8
    t.integer  "group_id",      :limit => 8
    t.integer  "scorable_id",   :limit => 8
    t.string   "scorable_type"
    t.integer  "score"
    t.integer  "score_trigger"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "support_scores", ["id"], :name => "support_scores_id"

  create_table "survey_handles", :id => false, :force => true do |t|
    t.integer  "id",               :limit => 8,                    :null => false
    t.integer  "account_id",       :limit => 8
    t.integer  "surveyable_id",    :limit => 8
    t.string   "surveyable_type"
    t.string   "id_token"
    t.integer  "sent_while"
    t.integer  "response_note_id", :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "survey_id",        :limit => 8
    t.integer  "survey_result_id", :limit => 8
    t.boolean  "rated",                         :default => false
  end

  add_index "survey_handles", ["id"], :name => "survey_handles_id"

  create_table "survey_remarks", :id => false, :force => true do |t|
    t.integer  "id",               :limit => 8, :null => false
    t.integer  "account_id",       :limit => 8
    t.integer  "note_id",          :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "survey_result_id", :limit => 8
  end

  add_index "survey_remarks", ["id"], :name => "survey_remarks_id"

  create_table "survey_results", :id => false, :force => true do |t|
    t.integer  "id",               :limit => 8, :null => false
    t.integer  "account_id",       :limit => 8
    t.integer  "survey_id",        :limit => 8
    t.integer  "surveyable_id",    :limit => 8
    t.string   "surveyable_type"
    t.integer  "customer_id",      :limit => 8
    t.integer  "agent_id",         :limit => 8
    t.integer  "response_note_id", :limit => 8
    t.integer  "rating"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "group_id",         :limit => 8
  end

  add_index "survey_results", ["id"], :name => "survey_results_id"

  create_table "surveys", :force => true do |t|
    t.integer  "account_id",   :limit => 8
    t.text     "link_text"
    t.integer  "send_while"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "happy_text",                :default => "Awesome"
    t.string   "neutral_text",              :default => "Just Okay"
    t.string   "unhappy_text",              :default => "Not Good"
  end

  add_index "surveys", ["account_id"], :name => "index_account_id_on_surrveys"

  create_table "ticket_stats_2013_1", :id => false, :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.integer  "ticket_id",        :limit => 8
    t.datetime "created_at"
    t.integer  "created_hour"
    t.integer  "resolved_hour"
    t.integer  "received_tickets",              :default => 0, :null => false
    t.integer  "resolved_tickets",              :default => 0, :null => false
    t.integer  "num_of_reopens",                :default => 0, :null => false
    t.integer  "assigned_tickets",              :default => 0, :null => false
    t.integer  "num_of_reassigns",              :default => 0, :null => false
    t.integer  "fcr_tickets",                   :default => 0, :null => false
    t.integer  "sla_tickets",                   :default => 0, :null => false
  end

  add_index "ticket_stats_2013_1", ["account_id", "created_at"], :name => "index_ticket_stats_on_account_id_created_at"
  add_index "ticket_stats_2013_1", ["ticket_id", "account_id", "created_at"], :name => "index_ticket_stats_on_ticket_id_created_at_account_id", :unique => true

  create_table "ticket_stats_2013_10", :id => false, :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.integer  "ticket_id",        :limit => 8
    t.datetime "created_at"
    t.integer  "created_hour"
    t.integer  "resolved_hour"
    t.integer  "received_tickets",              :default => 0, :null => false
    t.integer  "resolved_tickets",              :default => 0, :null => false
    t.integer  "num_of_reopens",                :default => 0, :null => false
    t.integer  "assigned_tickets",              :default => 0, :null => false
    t.integer  "num_of_reassigns",              :default => 0, :null => false
    t.integer  "fcr_tickets",                   :default => 0, :null => false
    t.integer  "sla_tickets",                   :default => 0, :null => false
  end

  add_index "ticket_stats_2013_10", ["account_id", "created_at"], :name => "index_ticket_stats_on_account_id_created_at"
  add_index "ticket_stats_2013_10", ["ticket_id", "account_id", "created_at"], :name => "index_ticket_stats_on_ticket_id_created_at_account_id", :unique => true

  create_table "ticket_stats_2013_11", :id => false, :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.integer  "ticket_id",        :limit => 8
    t.datetime "created_at"
    t.integer  "created_hour"
    t.integer  "resolved_hour"
    t.integer  "received_tickets",              :default => 0, :null => false
    t.integer  "resolved_tickets",              :default => 0, :null => false
    t.integer  "num_of_reopens",                :default => 0, :null => false
    t.integer  "assigned_tickets",              :default => 0, :null => false
    t.integer  "num_of_reassigns",              :default => 0, :null => false
    t.integer  "fcr_tickets",                   :default => 0, :null => false
    t.integer  "sla_tickets",                   :default => 0, :null => false
  end

  add_index "ticket_stats_2013_11", ["account_id", "created_at"], :name => "index_ticket_stats_on_account_id_created_at"
  add_index "ticket_stats_2013_11", ["ticket_id", "account_id", "created_at"], :name => "index_ticket_stats_on_ticket_id_created_at_account_id", :unique => true

  create_table "ticket_stats_2013_12", :id => false, :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.integer  "ticket_id",        :limit => 8
    t.datetime "created_at"
    t.integer  "created_hour"
    t.integer  "resolved_hour"
    t.integer  "received_tickets",              :default => 0, :null => false
    t.integer  "resolved_tickets",              :default => 0, :null => false
    t.integer  "num_of_reopens",                :default => 0, :null => false
    t.integer  "assigned_tickets",              :default => 0, :null => false
    t.integer  "num_of_reassigns",              :default => 0, :null => false
    t.integer  "fcr_tickets",                   :default => 0, :null => false
    t.integer  "sla_tickets",                   :default => 0, :null => false
  end

  add_index "ticket_stats_2013_12", ["account_id", "created_at"], :name => "index_ticket_stats_on_account_id_created_at"
  add_index "ticket_stats_2013_12", ["ticket_id", "account_id", "created_at"], :name => "index_ticket_stats_on_ticket_id_created_at_account_id", :unique => true

  create_table "ticket_stats_2013_2", :id => false, :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.integer  "ticket_id",        :limit => 8
    t.datetime "created_at"
    t.integer  "created_hour"
    t.integer  "resolved_hour"
    t.integer  "received_tickets",              :default => 0, :null => false
    t.integer  "resolved_tickets",              :default => 0, :null => false
    t.integer  "num_of_reopens",                :default => 0, :null => false
    t.integer  "assigned_tickets",              :default => 0, :null => false
    t.integer  "num_of_reassigns",              :default => 0, :null => false
    t.integer  "fcr_tickets",                   :default => 0, :null => false
    t.integer  "sla_tickets",                   :default => 0, :null => false
  end

  add_index "ticket_stats_2013_2", ["account_id", "created_at"], :name => "index_ticket_stats_on_account_id_created_at"
  add_index "ticket_stats_2013_2", ["ticket_id", "account_id", "created_at"], :name => "index_ticket_stats_on_ticket_id_created_at_account_id", :unique => true

  create_table "ticket_stats_2013_3", :id => false, :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.integer  "ticket_id",        :limit => 8
    t.datetime "created_at"
    t.integer  "created_hour"
    t.integer  "resolved_hour"
    t.integer  "received_tickets",              :default => 0, :null => false
    t.integer  "resolved_tickets",              :default => 0, :null => false
    t.integer  "num_of_reopens",                :default => 0, :null => false
    t.integer  "assigned_tickets",              :default => 0, :null => false
    t.integer  "num_of_reassigns",              :default => 0, :null => false
    t.integer  "fcr_tickets",                   :default => 0, :null => false
    t.integer  "sla_tickets",                   :default => 0, :null => false
  end

  add_index "ticket_stats_2013_3", ["account_id", "created_at"], :name => "index_ticket_stats_on_account_id_created_at"
  add_index "ticket_stats_2013_3", ["ticket_id", "account_id", "created_at"], :name => "index_ticket_stats_on_ticket_id_created_at_account_id", :unique => true

  create_table "ticket_stats_2013_4", :id => false, :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.integer  "ticket_id",        :limit => 8
    t.datetime "created_at"
    t.integer  "created_hour"
    t.integer  "resolved_hour"
    t.integer  "received_tickets",              :default => 0, :null => false
    t.integer  "resolved_tickets",              :default => 0, :null => false
    t.integer  "num_of_reopens",                :default => 0, :null => false
    t.integer  "assigned_tickets",              :default => 0, :null => false
    t.integer  "num_of_reassigns",              :default => 0, :null => false
    t.integer  "fcr_tickets",                   :default => 0, :null => false
    t.integer  "sla_tickets",                   :default => 0, :null => false
  end

  add_index "ticket_stats_2013_4", ["account_id", "created_at"], :name => "index_ticket_stats_on_account_id_created_at"
  add_index "ticket_stats_2013_4", ["ticket_id", "account_id", "created_at"], :name => "index_ticket_stats_on_ticket_id_created_at_account_id", :unique => true

  create_table "ticket_stats_2013_5", :id => false, :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.integer  "ticket_id",        :limit => 8
    t.datetime "created_at"
    t.integer  "created_hour"
    t.integer  "resolved_hour"
    t.integer  "received_tickets",              :default => 0, :null => false
    t.integer  "resolved_tickets",              :default => 0, :null => false
    t.integer  "num_of_reopens",                :default => 0, :null => false
    t.integer  "assigned_tickets",              :default => 0, :null => false
    t.integer  "num_of_reassigns",              :default => 0, :null => false
    t.integer  "fcr_tickets",                   :default => 0, :null => false
    t.integer  "sla_tickets",                   :default => 0, :null => false
  end

  add_index "ticket_stats_2013_5", ["account_id", "created_at"], :name => "index_ticket_stats_on_account_id_created_at"
  add_index "ticket_stats_2013_5", ["ticket_id", "account_id", "created_at"], :name => "index_ticket_stats_on_ticket_id_created_at_account_id", :unique => true

  create_table "ticket_stats_2013_6", :id => false, :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.integer  "ticket_id",        :limit => 8
    t.datetime "created_at"
    t.integer  "created_hour"
    t.integer  "resolved_hour"
    t.integer  "received_tickets",              :default => 0, :null => false
    t.integer  "resolved_tickets",              :default => 0, :null => false
    t.integer  "num_of_reopens",                :default => 0, :null => false
    t.integer  "assigned_tickets",              :default => 0, :null => false
    t.integer  "num_of_reassigns",              :default => 0, :null => false
    t.integer  "fcr_tickets",                   :default => 0, :null => false
    t.integer  "sla_tickets",                   :default => 0, :null => false
  end

  add_index "ticket_stats_2013_6", ["account_id", "created_at"], :name => "index_ticket_stats_on_account_id_created_at"
  add_index "ticket_stats_2013_6", ["ticket_id", "account_id", "created_at"], :name => "index_ticket_stats_on_ticket_id_created_at_account_id", :unique => true

  create_table "ticket_stats_2013_7", :id => false, :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.integer  "ticket_id",        :limit => 8
    t.datetime "created_at"
    t.integer  "created_hour"
    t.integer  "resolved_hour"
    t.integer  "received_tickets",              :default => 0, :null => false
    t.integer  "resolved_tickets",              :default => 0, :null => false
    t.integer  "num_of_reopens",                :default => 0, :null => false
    t.integer  "assigned_tickets",              :default => 0, :null => false
    t.integer  "num_of_reassigns",              :default => 0, :null => false
    t.integer  "fcr_tickets",                   :default => 0, :null => false
    t.integer  "sla_tickets",                   :default => 0, :null => false
  end

  add_index "ticket_stats_2013_7", ["account_id", "created_at"], :name => "index_ticket_stats_on_account_id_created_at"
  add_index "ticket_stats_2013_7", ["ticket_id", "account_id", "created_at"], :name => "index_ticket_stats_on_ticket_id_created_at_account_id", :unique => true

  create_table "ticket_stats_2013_8", :id => false, :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.integer  "ticket_id",        :limit => 8
    t.datetime "created_at"
    t.integer  "created_hour"
    t.integer  "resolved_hour"
    t.integer  "received_tickets",              :default => 0, :null => false
    t.integer  "resolved_tickets",              :default => 0, :null => false
    t.integer  "num_of_reopens",                :default => 0, :null => false
    t.integer  "assigned_tickets",              :default => 0, :null => false
    t.integer  "num_of_reassigns",              :default => 0, :null => false
    t.integer  "fcr_tickets",                   :default => 0, :null => false
    t.integer  "sla_tickets",                   :default => 0, :null => false
  end

  add_index "ticket_stats_2013_8", ["account_id", "created_at"], :name => "index_ticket_stats_on_account_id_created_at"
  add_index "ticket_stats_2013_8", ["ticket_id", "account_id", "created_at"], :name => "index_ticket_stats_on_ticket_id_created_at_account_id", :unique => true

  create_table "ticket_stats_2013_9", :id => false, :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.integer  "ticket_id",        :limit => 8
    t.datetime "created_at"
    t.integer  "created_hour"
    t.integer  "resolved_hour"
    t.integer  "received_tickets",              :default => 0, :null => false
    t.integer  "resolved_tickets",              :default => 0, :null => false
    t.integer  "num_of_reopens",                :default => 0, :null => false
    t.integer  "assigned_tickets",              :default => 0, :null => false
    t.integer  "num_of_reassigns",              :default => 0, :null => false
    t.integer  "fcr_tickets",                   :default => 0, :null => false
    t.integer  "sla_tickets",                   :default => 0, :null => false
  end

  add_index "ticket_stats_2013_9", ["account_id", "created_at"], :name => "index_ticket_stats_on_account_id_created_at"
  add_index "ticket_stats_2013_9", ["ticket_id", "account_id", "created_at"], :name => "index_ticket_stats_on_ticket_id_created_at_account_id", :unique => true

  create_table "ticket_topics", :force => true do |t|
    t.integer  "ticket_id",  :limit => 8
    t.integer  "topic_id",   :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id", :limit => 8
  end

  add_index "ticket_topics", ["account_id", "ticket_id"], :name => "index_account_id_and_ticket_id_on_ticket_topics"

  create_table "topics", :force => true do |t|
    t.integer  "forum_id",     :limit => 8
    t.integer  "user_id",      :limit => 8
    t.string   "title"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "hits",                      :default => 0
    t.integer  "sticky",                    :default => 0
    t.integer  "posts_count",               :default => 0
    t.datetime "replied_at"
    t.boolean  "locked",                    :default => false
    t.integer  "replied_by",   :limit => 8
    t.integer  "last_post_id", :limit => 8
    t.integer  "account_id",   :limit => 8
    t.integer  "stamp_type"
    t.boolean  "delta",                     :default => true,  :null => false
    t.integer  "import_id",    :limit => 8
    t.integer  "user_votes",                :default => 0
  end

  add_index "topics", ["forum_id", "replied_at"], :name => "index_topics_on_forum_id_and_replied_at"
  add_index "topics", ["forum_id", "sticky", "replied_at"], :name => "index_topics_on_sticky_and_replied_at"
  add_index "topics", ["forum_id"], :name => "index_topics_on_forum_id"

  create_table "user_roles", :id => false, :force => true do |t|
    t.integer "user_id",    :limit => 8
    t.integer "role_id",    :limit => 8
    t.integer "account_id", :limit => 8
  end

  add_index "user_roles", ["role_id"], :name => "index_user_roles_on_role_id"
  add_index "user_roles", ["user_id"], :name => "index_user_roles_on_user_id"

  create_table "users", :id => false, :force => true do |t|
    t.integer  "id",                  :limit => 8,                    :null => false
    t.string   "name",                             :default => "",    :null => false
    t.string   "email"
    t.string   "crypted_password"
    t.string   "password_salt"
    t.string   "persistence_token",                                   :null => false
    t.datetime "last_login_at"
    t.datetime "current_login_at"
    t.string   "last_login_ip"
    t.string   "current_login_ip"
    t.integer  "login_count",                      :default => 0,     :null => false
    t.integer  "failed_login_count",               :default => 0,     :null => false
    t.string   "single_access_token"
    t.string   "perishable_token"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id",          :limit => 8
    t.boolean  "active",                           :default => false, :null => false
    t.integer  "customer_id",         :limit => 8
    t.string   "job_title"
    t.string   "second_email"
    t.string   "phone"
    t.string   "mobile"
    t.string   "twitter_id"
    t.text     "description"
    t.string   "time_zone"
    t.integer  "posts_count",                      :default => 0
    t.datetime "last_seen_at"
    t.boolean  "deleted",                          :default => false
    t.integer  "user_role"
    t.boolean  "delta",                            :default => true,  :null => false
    t.integer  "import_id",           :limit => 8
    t.string   "fb_profile_id"
    t.string   "language",                         :default => "en"
    t.boolean  "blocked",                          :default => false
    t.datetime "blocked_at"
    t.string   "address"
    t.datetime "deleted_at"
    t.boolean  "whitelisted",                      :default => false
    t.string   "external_id"
    t.string   "string_uc01"
    t.text     "text_uc01"
    t.boolean  "helpdesk_agent",                   :default => false
    t.string   "privileges",                       :default => "0"
  end

  add_index "users", ["account_id", "email"], :name => "index_users_on_account_id_and_email", :unique => true
  add_index "users", ["account_id", "external_id"], :name => "index_users_on_account_id_and_external_id", :unique => true, :length => {"external_id"=>"20", "account_id"=>nil}
  add_index "users", ["account_id", "import_id"], :name => "index_users_on_account_id_and_import_id", :unique => true
  add_index "users", ["id"], :name => "users_id"
  add_index "users", ["perishable_token", "account_id"], :name => "index_users_on_perishable_token_and_account_id"
  add_index "users", ["persistence_token", "account_id"], :name => "index_users_on_persistence_token_and_account_id"
  add_index "users", ["single_access_token", "account_id"], :name => "index_users_on_account_id_and_single_access_token", :unique => true

  create_table "va_rules", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.string   "match_type"
    t.text     "filter_data"
    t.text     "action_data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id",  :limit => 8
    t.integer  "rule_type"
    t.boolean  "active"
    t.integer  "position"
  end

  add_index "va_rules", ["account_id", "rule_type"], :name => "index_va_rules_on_account_id_and_rule_type"

  create_table "votes", :force => true do |t|
    t.boolean  "vote",                        :default => false
    t.datetime "created_at",                                     :null => false
    t.string   "voteable_type", :limit => 15, :default => "",    :null => false
    t.integer  "voteable_id",   :limit => 8,  :default => 0,     :null => false
    t.integer  "user_id",       :limit => 8,  :default => 0,     :null => false
    t.integer  "account_id",    :limit => 8
  end

  add_index "votes", ["user_id"], :name => "fk_votes_user"

  create_table "wf_filters", :force => true do |t|
    t.string   "type"
    t.string   "name"
    t.text     "data"
    t.integer  "user_id"
    t.string   "model_class_name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id"
  end

  add_index "wf_filters", ["user_id"], :name => "index_wf_filters_on_user_id"

  create_table "widgets", :force => true do |t|
    t.string  "name"
    t.string  "description"
    t.text    "script"
    t.integer "application_id"
    t.text    "options"
  end

end
