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


ActiveRecord::Schema.define(:version => 20110212141352) do

  create_table "accounts", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "full_domain"
    t.datetime "deleted_at"
    t.string   "default_email"
    t.string   "time_zone"
    t.string   "helpdesk_name"
    t.text     "helpdesk_url"
    t.string   "bg_color"
    t.string   "header_color"
  end

  add_index "accounts", ["full_domain"], :name => "index_accounts_on_full_domain"

  create_table "agent_groups", :force => true do |t|
    t.integer  "user_id"
    t.integer  "group_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "agents", :force => true do |t|
    t.integer  "user_id"
    t.text     "signature"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "business_calendars", :force => true do |t|
    t.integer  "account_id"
    t.text     "business_time_data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "holidays"
  end

  create_table "customers", :force => true do |t|
    t.string   "name"
    t.string   "cust_identifier"
    t.integer  "account_id"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "sla_policy_id"
    t.text     "note"
    t.text     "domains"
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
    t.integer  "account_id"
    t.string   "to_email"
    t.string   "reply_email"
    t.integer  "group_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "email_notifications", :force => true do |t|
    t.integer  "account_id"
    t.boolean  "requester_notification"
    t.text     "requester_template"
    t.boolean  "agent_notification"
    t.text     "agent_template"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "notification_type"
  end

  create_table "flexifield_def_entries", :force => true do |t|
    t.integer  "flexifield_def_id",  :null => false
    t.string   "flexifield_name",    :null => false
    t.string   "flexifield_alias",   :null => false
    t.string   "flexifield_tooltip"
    t.integer  "flexifield_order"
    t.string   "flexifield_coltype"
    t.string   "flexifield_defVal"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "flexifield_def_entries", ["flexifield_def_id", "flexifield_name"], :name => "idx_ffde_onceperdef", :unique => true
  add_index "flexifield_def_entries", ["flexifield_def_id", "flexifield_order"], :name => "idx_ffde_ordering"

  create_table "flexifield_defs", :force => true do |t|
    t.string   "name",       :null => false
    t.integer  "account_id"
    t.string   "module"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "flexifield_defs", ["name", "account_id"], :name => "idx_ffd_onceperdef", :unique => true

  create_table "flexifield_picklist_vals", :force => true do |t|
    t.integer  "flexifield_def_entry_id", :null => false
    t.string   "value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "flexifields", :force => true do |t|
    t.integer  "flexifield_def_id"
    t.integer  "flexifield_set_id"
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
    t.integer  "account_id"
  end

  create_table "forums", :force => true do |t|
    t.string  "name"
    t.string  "description"
    t.integer "topics_count",      :default => 0
    t.integer "posts_count",       :default => 0
    t.integer "position"
    t.text    "description_html"
    t.integer "account_id"
    t.integer "forum_category_id"
    t.integer "forum_type"
  end

  create_table "groups", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "account_id"
    t.boolean  "email_on_assign"
    t.integer  "escalate_to"
    t.integer  "assign_time"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "helpdesk_activities", :force => true do |t|
    t.integer  "account_id"
    t.text     "description"
    t.integer  "notable_id"
    t.string   "notable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_id"
    t.text     "activity_data"
    t.text     "short_descr"
  end

  create_table "helpdesk_article_guides", :force => true do |t|
    t.integer  "article_id"
    t.integer  "guide_id"
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "helpdesk_article_guides", ["article_id"], :name => "index_helpdesk_article_sections_on_article_id"
  add_index "helpdesk_article_guides", ["guide_id"], :name => "index_helpdesk_article_sections_on_section_id"

  create_table "helpdesk_articles", :force => true do |t|
    t.string   "title"
    t.text     "body"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id"
    t.integer  "status"
    t.boolean  "is_public",  :default => true
    t.integer  "sol_type"
  end

  create_table "helpdesk_attachments", :force => true do |t|
    t.text     "description"
    t.string   "content_file_name"
    t.string   "content_content_type"
    t.integer  "content_file_size"
    t.integer  "content_updated_at"
    t.integer  "attachable_id"
    t.string   "attachable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id"
  end

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
    t.integer  "account_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "agent_view"
    t.text     "requester_view"
  end

  create_table "helpdesk_guides", :force => true do |t|
    t.string   "name"
    t.boolean  "hidden",               :default => false
    t.integer  "article_guides_count"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "position",             :default => 0
    t.text     "description"
    t.integer  "account_id"
    t.integer  "folder_id"
  end

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
    t.integer  "user_id"
    t.integer  "source",       :default => 0
    t.boolean  "incoming",     :default => false
    t.boolean  "private",      :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "deleted",      :default => false
    t.integer  "notable_id"
    t.string   "notable_type"
    t.integer  "account_id"
  end

  add_index "helpdesk_notes", ["notable_id"], :name => "index_helpdesk_notes_on_notable_id"
  add_index "helpdesk_notes", ["notable_type"], :name => "index_helpdesk_notes_on_notable_type"

  create_table "helpdesk_reminders", :force => true do |t|
    t.string   "body"
    t.boolean  "deleted",    :default => false
    t.integer  "user_id"
    t.integer  "ticket_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "helpdesk_reminders", ["ticket_id"], :name => "index_helpdesk_reminders_on_ticket_id"
  add_index "helpdesk_reminders", ["user_id"], :name => "index_helpdesk_reminders_on_user_id"

  create_table "helpdesk_sla_details", :force => true do |t|
    t.string   "name"
    t.integer  "priority"
    t.integer  "response_time"
    t.integer  "resolution_time"
    t.integer  "escalateto"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "sla_policy_id"
    t.boolean  "override_bhrs"
  end

  create_table "helpdesk_sla_policies", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "account_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "is_default",  :default => false
  end

  create_table "helpdesk_subscriptions", :force => true do |t|
    t.integer  "user_id"
    t.integer  "ticket_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "helpdesk_subscriptions", ["ticket_id"], :name => "index_helpdesk_subscriptions_on_ticket_id"
  add_index "helpdesk_subscriptions", ["user_id"], :name => "index_helpdesk_subscriptions_on_user_id"

  create_table "helpdesk_support_plans", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "account_id"
    t.boolean  "email"
    t.boolean  "phone"
    t.boolean  "community"
    t.boolean  "twitter"
    t.boolean  "facebook"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "helpdesk_tag_uses", :force => true do |t|
    t.integer "ticket_id", :null => false
    t.integer "tag_id",    :null => false
  end

  add_index "helpdesk_tag_uses", ["tag_id"], :name => "index_helpdesk_tag_uses_on_tag_id"
  add_index "helpdesk_tag_uses", ["ticket_id"], :name => "index_helpdesk_tag_uses_on_ticket_id"

  create_table "helpdesk_tags", :force => true do |t|
    t.string  "name"
    t.integer "tag_uses_count"
    t.integer "account_id"
  end

  create_table "helpdesk_ticket_issues", :force => true do |t|
    t.integer "ticket_id"
    t.integer "issue_id"
  end

  add_index "helpdesk_ticket_issues", ["issue_id"], :name => "index_helpdesk_ticket_issues_on_issue_id"
  add_index "helpdesk_ticket_issues", ["ticket_id"], :name => "index_helpdesk_ticket_issues_on_ticket_id"

  create_table "helpdesk_tickets", :force => true do |t|
    t.string   "id_token"
    t.string   "access_token"
    t.text     "description"
    t.integer  "requester_id"
    t.integer  "responder_id"
    t.integer  "status",            :default => 1
    t.boolean  "urgent",            :default => false
    t.integer  "source",            :default => 0
    t.boolean  "spam",              :default => false
    t.boolean  "deleted",           :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "trained",           :default => false
    t.integer  "account_id"
    t.string   "subject"
    t.integer  "display_id"
    t.integer  "organization_id"
    t.integer  "owner_id"
    t.integer  "group_id"
    t.datetime "first_assigned_at"
    t.datetime "assigned_at"
    t.datetime "due_by"
    t.datetime "completed_at"
    t.datetime "frDueBy"
    t.boolean  "isescalated",       :default => false
    t.integer  "priority",          :default => 1
    t.boolean  "fr_escalated",      :default => false
    t.datetime "response_time"
    t.integer  "ticket_type"
    t.string   "to_email"
    t.integer  "email_config_id"
  end

  add_index "helpdesk_tickets", ["id_token"], :name => "index_helpdesk_tickets_on_id_token", :unique => true
  add_index "helpdesk_tickets", ["requester_id"], :name => "index_helpdesk_tickets_on_requester_id"
  add_index "helpdesk_tickets", ["responder_id"], :name => "index_helpdesk_tickets_on_responder_id"

  create_table "moderatorships", :force => true do |t|
    t.integer "forum_id"
    t.integer "user_id"
  end

  add_index "moderatorships", ["forum_id"], :name => "index_moderatorships_on_forum_id"

  create_table "monitorships", :force => true do |t|
    t.integer "topic_id"
    t.integer "user_id"
    t.boolean "active",   :default => true
  end

  create_table "password_resets", :force => true do |t|
    t.string   "email"
    t.integer  "user_id"
    t.string   "remote_ip"
    t.string   "token"
    t.datetime "created_at"
  end

  create_table "posts", :force => true do |t|
    t.integer  "user_id"
    t.integer  "topic_id"
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "forum_id"
    t.text     "body_html"
    t.integer  "account_id"
    t.boolean  "answer",     :default => false
  end

  add_index "posts", ["forum_id", "created_at"], :name => "index_posts_on_forum_id"
  add_index "posts", ["topic_id", "created_at"], :name => "index_posts_on_topic_id"
  add_index "posts", ["user_id", "created_at"], :name => "index_posts_on_user_id"

  create_table "solution_articles", :force => true do |t|
    t.string   "title"
    t.text     "description"
    t.integer  "user_id"
    t.integer  "folder_id"
    t.integer  "status"
    t.integer  "art_type"
    t.boolean  "is_public"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "solution_categories", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "account_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "solution_folders", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "category_id"
  end

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
    t.decimal  "amount",                 :precision => 6, :scale => 2, :default => 0.0
    t.boolean  "percent"
    t.date     "start_on"
    t.date     "end_on"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "apply_to_setup",                                       :default => true
    t.boolean  "apply_to_recurring",                                   :default => true
    t.integer  "trial_period_extension",                               :default => 0
  end

  create_table "subscription_payments", :force => true do |t|
    t.integer  "account_id"
    t.integer  "subscription_id"
    t.decimal  "amount",                    :precision => 10, :scale => 2, :default => 0.0
    t.string   "transaction_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "setup"
    t.boolean  "misc"
    t.integer  "subscription_affiliate_id"
    t.decimal  "affiliate_amount",          :precision => 6,  :scale => 2, :default => 0.0
  end

  add_index "subscription_payments", ["account_id"], :name => "index_subscription_payments_on_account_id"
  add_index "subscription_payments", ["subscription_id"], :name => "index_subscription_payments_on_subscription_id"

  create_table "subscription_plans", :force => true do |t|
    t.string   "name"
    t.decimal  "amount",         :precision => 10, :scale => 2
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "user_limit"
    t.integer  "renewal_period",                                :default => 1
    t.decimal  "setup_amount",   :precision => 10, :scale => 2
    t.integer  "trial_period",                                  :default => 1
  end

  create_table "subscriptions", :force => true do |t|
    t.decimal  "amount",                    :precision => 10, :scale => 2
    t.datetime "next_renewal_at"
    t.string   "card_number"
    t.string   "card_expiration"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "state",                                                    :default => "trial"
    t.integer  "subscription_plan_id"
    t.integer  "account_id"
    t.integer  "user_limit"
    t.integer  "renewal_period",                                           :default => 1
    t.string   "billing_id"
    t.integer  "subscription_discount_id"
    t.integer  "subscription_affiliate_id"
  end

  add_index "subscriptions", ["account_id"], :name => "index_subscriptions_on_account_id"

  create_table "ticket_topics", :force => true do |t|
    t.integer  "ticket_id"
    t.integer  "topic_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "topics", :force => true do |t|
    t.integer  "forum_id"
    t.integer  "user_id"
    t.string   "title"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "hits",         :default => 0
    t.integer  "sticky",       :default => 0
    t.integer  "posts_count",  :default => 0
    t.datetime "replied_at"
    t.boolean  "locked",       :default => false
    t.integer  "replied_by"
    t.integer  "last_post_id"
    t.integer  "account_id"
    t.integer  "stamp_type"
  end

  add_index "topics", ["forum_id", "replied_at"], :name => "index_topics_on_forum_id_and_replied_at"
  add_index "topics", ["forum_id", "sticky", "replied_at"], :name => "index_topics_on_sticky_and_replied_at"
  add_index "topics", ["forum_id"], :name => "index_topics_on_forum_id"

  create_table "users", :force => true do |t|
    t.string   "name",                :default => "",    :null => false
    t.string   "email"
    t.string   "crypted_password"
    t.string   "password_salt"
    t.string   "persistence_token",                      :null => false
    t.datetime "last_login_at"
    t.datetime "current_login_at"
    t.string   "last_login_ip"
    t.string   "current_login_ip"
    t.integer  "login_count",         :default => 0,     :null => false
    t.integer  "failed_login_count",  :default => 0,     :null => false
    t.datetime "last_request_at"
    t.string   "single_access_token"
    t.string   "perishable_token"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id"
    t.boolean  "admin",               :default => false
    t.boolean  "active",              :default => false, :null => false
    t.string   "role_token"
    t.integer  "customer_id"
    t.string   "job_title"
    t.string   "second_email"
    t.string   "phone"
    t.string   "mobile"
    t.string   "twitter_id"
    t.text     "description"
    t.string   "time_zone"
    t.integer  "posts_count",         :default => 0
    t.datetime "last_seen_at"
  end

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
    t.integer  "account_id"
    t.integer  "rule_type"
    t.boolean  "active"
    t.integer  "position"
  end

  create_table "virtual_agents", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "votes", :force => true do |t|
    t.boolean  "vote",                        :default => false
    t.datetime "created_at",                                     :null => false
    t.string   "voteable_type", :limit => 15, :default => "",    :null => false
    t.integer  "voteable_id",                 :default => 0,     :null => false
    t.integer  "user_id",                     :default => 0,     :null => false
  end

  add_index "votes", ["user_id"], :name => "fk_votes_user"

end
