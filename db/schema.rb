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

ActiveRecord::Schema.define(:version => 20110824144030) do

  create_table "accounts", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "full_domain"
    t.datetime "deleted_at"
    t.string   "time_zone"
    t.string   "helpdesk_name"
    t.string   "helpdesk_url"
    t.text     "preferences"
    t.integer  "ticket_display_id", :limit => 8, :default => 0
    t.boolean  "sso_enabled",                    :default => false
    t.string   "shared_secret"
    t.text     "sso_options"
    t.string   "google_domain"
  end

  add_index "accounts", ["full_domain"], :name => "index_accounts_on_full_domain", :unique => true
  add_index "accounts", ["helpdesk_url"], :name => "index_accounts_on_helpdesk_url"

  create_table "admin_canned_responses", :force => true do |t|
    t.string   "title"
    t.text     "content",    :limit => 2147483647
    t.integer  "account_id", :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "admin_canned_responses", ["account_id", "created_at"], :name => "index_admin_canned_responses_on_account_id_and_created_at"

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

  add_index "admin_user_accesses", ["account_id", "created_at"], :name => "index_admin_user_accesses_on_account_id_and_created_at"
  add_index "admin_user_accesses", ["user_id"], :name => "index_admin_user_accesses_on_user_id"

  create_table "agent_groups", :force => true do |t|
    t.integer  "user_id",    :limit => 8
    t.integer  "group_id",   :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "agents", :force => true do |t|
    t.integer  "user_id",    :limit => 8
    t.text     "signature"
    t.datetime "created_at"
    t.datetime "updated_at"
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
  end

  add_index "business_calendars", ["account_id"], :name => "index_business_calendars_on_account_id"

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
  end

  add_index "email_configs", ["account_id", "to_email"], :name => "index_email_configs_on_account_id_and_to_email", :unique => true

  create_table "email_notifications", :force => true do |t|
    t.integer  "account_id",             :limit => 8
    t.boolean  "requester_notification"
    t.text     "requester_template"
    t.boolean  "agent_notification"
    t.text     "agent_template"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "notification_type"
  end

  add_index "email_notifications", ["account_id", "notification_type"], :name => "index_email_notifications_on_notification_type", :unique => true

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
  end

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

  create_table "flexifields", :force => true do |t|
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
  end

  add_index "flexifields", ["flexifield_def_id"], :name => "index_flexifields_on_flexifield_def_id"
  add_index "flexifields", ["flexifield_set_id", "flexifield_set_type"], :name => "idx_ff_poly"

  create_table "forum_categories", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id",  :limit => 8
    t.integer  "import_id",   :limit => 8
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

  create_table "groups", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "account_id",      :limit => 8
    t.boolean  "email_on_assign"
    t.integer  "escalate_to",     :limit => 8
    t.integer  "assign_time"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "import_id",       :limit => 8
  end

  add_index "groups", ["account_id", "name"], :name => "index_groups_on_account_id", :unique => true

  create_table "helpdesk_activities", :force => true do |t|
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

  create_table "helpdesk_attachments", :force => true do |t|
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

  add_index "helpdesk_attachments", ["attachable_id"], :name => "index_helpdesk_attachments_on_attachable_id"

  create_table "helpdesk_authorizations", :force => true do |t|
    t.string   "role_token"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "helpdesk_authorizations", ["role_token"], :name => "index_helpdesk_authorizations_on_role_token"
  add_index "helpdesk_authorizations", ["user_id"], :name => "index_helpdesk_authorizations_on_user_id"

  create_table "helpdesk_classifiers", :force => true do |t|
    t.string "name",       :null => false
    t.string "categories", :null => false
    t.binary "data"
  end

  create_table "helpdesk_form_customizers", :force => true do |t|
    t.string   "name"
    t.text     "json_data"
    t.integer  "account_id",     :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "agent_view"
    t.text     "requester_view"
  end

  add_index "helpdesk_form_customizers", ["account_id"], :name => "index_helpdesk_form_customizers_on_account_id", :unique => true

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

  create_table "helpdesk_notes", :force => true do |t|
    t.text     "body"
    t.integer  "user_id",      :limit => 8
    t.integer  "source",                    :default => 0
    t.boolean  "incoming",                  :default => false
    t.boolean  "private",                   :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "deleted",                   :default => false
    t.integer  "notable_id",   :limit => 8
    t.string   "notable_type"
    t.integer  "account_id",   :limit => 8
  end

  add_index "helpdesk_notes", ["account_id", "notable_type", "notable_id"], :name => "index_helpdesk_notes_on_notables"
  add_index "helpdesk_notes", ["notable_id"], :name => "index_helpdesk_notes_on_notable_id"
  add_index "helpdesk_notes", ["notable_type"], :name => "index_helpdesk_notes_on_notable_type"

  create_table "helpdesk_picklist_values", :force => true do |t|
    t.integer  "pickable_id",   :limit => 8
    t.string   "pickable_type"
    t.integer  "position"
    t.string   "value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "helpdesk_reminders", :force => true do |t|
    t.string   "body"
    t.boolean  "deleted",                 :default => false
    t.integer  "user_id",    :limit => 8
    t.integer  "ticket_id",  :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "helpdesk_reminders", ["ticket_id"], :name => "index_helpdesk_reminders_on_ticket_id"
  add_index "helpdesk_reminders", ["user_id"], :name => "index_helpdesk_reminders_on_user_id"

  create_table "helpdesk_sla_details", :force => true do |t|
    t.string   "name"
    t.integer  "priority",        :limit => 8
    t.integer  "response_time"
    t.integer  "resolution_time"
    t.integer  "escalateto",      :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "sla_policy_id",   :limit => 8
    t.boolean  "override_bhrs",                :default => false
  end

  create_table "helpdesk_sla_policies", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "account_id",  :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "is_default",               :default => false
  end

  add_index "helpdesk_sla_policies", ["account_id", "name"], :name => "index_helpdesk_sla_policies_on_account_id_and_name", :unique => true

  create_table "helpdesk_subscriptions", :force => true do |t|
    t.integer  "user_id",    :limit => 8
    t.integer  "ticket_id",  :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "helpdesk_subscriptions", ["ticket_id"], :name => "index_helpdesk_subscriptions_on_ticket_id"
  add_index "helpdesk_subscriptions", ["user_id"], :name => "index_helpdesk_subscriptions_on_user_id"

  create_table "helpdesk_tag_uses", :force => true do |t|
    t.integer "tag_id",        :limit => 8, :null => false
    t.string  "taggable_type"
    t.integer "taggable_id",   :limit => 8
  end

  add_index "helpdesk_tag_uses", ["tag_id"], :name => "index_helpdesk_tag_uses_on_tag_id"

  create_table "helpdesk_tags", :force => true do |t|
    t.string  "name"
    t.integer "tag_uses_count"
    t.integer "account_id",     :limit => 8
  end

  add_index "helpdesk_tags", ["account_id", "name"], :name => "index_helpdesk_tags_on_account_id_and_name", :unique => true

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
  end

  add_index "helpdesk_ticket_fields", ["account_id", "name"], :name => "index_helpdesk_ticket_fields_on_account_id_and_name", :unique => true

  create_table "helpdesk_ticket_issues", :force => true do |t|
    t.integer "ticket_id"
    t.integer "issue_id"
  end

  add_index "helpdesk_ticket_issues", ["issue_id"], :name => "index_helpdesk_ticket_issues_on_issue_id"
  add_index "helpdesk_ticket_issues", ["ticket_id"], :name => "index_helpdesk_ticket_issues_on_ticket_id"

  create_table "helpdesk_ticket_states", :force => true do |t|
    t.integer  "ticket_id",              :limit => 8
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
    t.boolean  "group_escalated",                     :default => false
    t.integer  "inbound_count",                       :default => 1
  end

  create_table "helpdesk_tickets", :force => true do |t|
    t.text     "description"
    t.integer  "requester_id",    :limit => 8
    t.integer  "responder_id",    :limit => 8
    t.integer  "status",          :limit => 8, :default => 1
    t.boolean  "urgent",                       :default => false
    t.integer  "source",                       :default => 0
    t.boolean  "spam",                         :default => false
    t.boolean  "deleted",                      :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "trained",                      :default => false
    t.integer  "account_id",      :limit => 8
    t.string   "subject"
    t.integer  "display_id",      :limit => 8
    t.integer  "owner_id",        :limit => 8
    t.integer  "group_id",        :limit => 8
    t.datetime "due_by"
    t.datetime "frDueBy"
    t.boolean  "isescalated",                  :default => false
    t.integer  "priority",        :limit => 8, :default => 1
    t.boolean  "fr_escalated",                 :default => false
    t.string   "to_email"
    t.integer  "email_config_id", :limit => 8
    t.text     "cc_email"
    t.boolean  "delta",                        :default => true,  :null => false
    t.integer  "import_id",       :limit => 8
    t.string   "ticket_type"
  end

  add_index "helpdesk_tickets", ["account_id", "display_id"], :name => "index_helpdesk_tickets_on_account_id_and_display_id", :unique => true
  add_index "helpdesk_tickets", ["account_id", "requester_id"], :name => "index_helpdesk_tickets_on_account_id_and_requester_id"
  add_index "helpdesk_tickets", ["account_id", "responder_id"], :name => "index_helpdesk_tickets_on_account_id_and_responder_id"

  create_table "moderatorships", :force => true do |t|
    t.integer "forum_id", :limit => 8
    t.integer "user_id",  :limit => 8
  end

  add_index "moderatorships", ["forum_id"], :name => "index_moderatorships_on_forum_id"

  create_table "monitorships", :force => true do |t|
    t.integer "topic_id", :limit => 8
    t.integer "user_id",  :limit => 8
    t.boolean "active",                :default => true
  end

  create_table "password_resets", :force => true do |t|
    t.string   "email"
    t.integer  "user_id",    :limit => 8
    t.string   "remote_ip"
    t.string   "token"
    t.datetime "created_at"
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

  create_table "social_tweets", :force => true do |t|
    t.integer  "tweet_id",       :limit => 8
    t.integer  "tweetable_id",   :limit => 8
    t.string   "tweetable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id"
  end

  create_table "social_twitter_handles", :force => true do |t|
    t.integer  "twitter_user_id",           :limit => 8
    t.string   "screen_name"
    t.string   "access_token"
    t.string   "access_secret"
    t.boolean  "capture_dm_as_ticket",                   :default => true
    t.boolean  "capture_mention_as_ticket",              :default => true
    t.integer  "product_id",                :limit => 8
    t.integer  "last_dm_id",                :limit => 8
    t.integer  "last_mention_id",           :limit => 8
    t.integer  "account_id"
    t.text     "search_keys"
    t.datetime "created_at"
    t.datetime "updated_at"
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
  end

  add_index "solution_categories", ["account_id", "name"], :name => "index_solution_categories_on_account_id_and_name", :unique => true

  create_table "solution_folders", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "category_id", :limit => 8
    t.integer  "import_id",   :limit => 8
    t.integer  "visibility",  :limit => 8
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
  end

  add_index "subscription_payments", ["account_id"], :name => "index_subscription_payments_on_account_id"
  add_index "subscription_payments", ["subscription_id"], :name => "index_subscription_payments_on_subscription_id"

  create_table "subscription_plans", :force => true do |t|
    t.string   "name"
    t.decimal  "amount",         :precision => 10, :scale => 2
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "renewal_period",                                :default => 1
    t.decimal  "setup_amount",   :precision => 10, :scale => 2
    t.integer  "trial_period",                                  :default => 1
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
  end

  add_index "subscriptions", ["account_id"], :name => "index_subscriptions_on_account_id"

  create_table "survey_handles", :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.integer  "surveyable_id",    :limit => 8
    t.string   "surveyable_type"
    t.string   "id_token"
    t.integer  "sent_while"
    t.integer  "response_note_id", :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "survey_points", :force => true do |t|
    t.integer  "survey_id",        :limit => 8
    t.integer  "resolution_speed"
    t.integer  "customer_rating"
    t.integer  "score"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "survey_remarks", :force => true do |t|
    t.integer  "survey_score_id", :limit => 8
    t.integer  "note_id",         :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "survey_scores", :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.integer  "surveyable_id",    :limit => 8
    t.string   "surveyable_type"
    t.integer  "customer_id",      :limit => 8
    t.integer  "agent_id",         :limit => 8
    t.integer  "response_note_id", :limit => 8
    t.integer  "resolution_speed"
    t.integer  "customer_rating"
    t.integer  "score"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "surveys", :force => true do |t|
    t.integer  "account_id", :limit => 8
    t.text     "link_text"
    t.integer  "send_while"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "ticket_topics", :force => true do |t|
    t.integer  "ticket_id",  :limit => 8
    t.integer  "topic_id",   :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

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
  end

  add_index "topics", ["forum_id", "replied_at"], :name => "index_topics_on_forum_id_and_replied_at"
  add_index "topics", ["forum_id", "sticky", "replied_at"], :name => "index_topics_on_sticky_and_replied_at"
  add_index "topics", ["forum_id"], :name => "index_topics_on_forum_id"

  create_table "users", :force => true do |t|
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
  end

  add_index "users", ["account_id", "email"], :name => "index_users_on_account_id_and_email", :unique => true
  add_index "users", ["account_id"], :name => "index_users_on_account_id"
  add_index "users", ["customer_id"], :name => "index_users_on_customer_id"
  add_index "users", ["email"], :name => "index_users_on_email"
  add_index "users", ["perishable_token"], :name => "index_users_on_perishable_token"
  add_index "users", ["persistence_token"], :name => "index_users_on_persistence_token"
  add_index "users", ["single_access_token"], :name => "index_users_on_single_access_token", :unique => true

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
  end

  add_index "wf_filters", ["user_id"], :name => "index_wf_filters_on_user_id"

end
