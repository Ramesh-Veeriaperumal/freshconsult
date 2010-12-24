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

ActiveRecord::Schema.define(:version => 20101218073860) do

  create_table "accounts", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "full_domain"
    t.datetime "deleted_at"
    t.string   "default_email"
  end

  add_index "accounts", ["full_domain"], :name => "index_accounts_on_full_domain"

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
    t.string   "ff_int01"
    t.string   "ff_int02"
    t.string   "ff_int03"
    t.string   "ff_int04"
    t.string   "ff_int05"
    t.string   "ff_int06"
    t.string   "ff_int07"
    t.string   "ff_int08"
    t.string   "ff_int09"
    t.string   "ff_int10"
    t.string   "ff_date01"
    t.string   "ff_date02"
    t.string   "ff_date03"
    t.string   "ff_date04"
    t.string   "ff_date05"
    t.string   "ff_date06"
    t.string   "ff_date07"
    t.string   "ff_date08"
    t.string   "ff_date09"
    t.string   "ff_date10"
  end

  add_index "flexifields", ["flexifield_def_id"], :name => "index_flexifields_on_flexifield_def_id"
  add_index "flexifields", ["flexifield_set_id", "flexifield_set_type"], :name => "idx_ff_poly"

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

  create_table "helpdesk_guides", :force => true do |t|
    t.string   "name"
    t.boolean  "hidden",               :default => false
    t.integer  "article_guides_count"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "position",             :default => 0
    t.text     "description"
    t.integer  "account_id"
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
    t.text     "description"
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
    t.integer  "account_id"
    t.integer  "priority"
    t.integer  "response_time"
    t.integer  "resolution_time"
    t.integer  "escalateto"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "helpdesk_subscriptions", :force => true do |t|
    t.integer  "user_id"
    t.integer  "ticket_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "helpdesk_subscriptions", ["ticket_id"], :name => "index_helpdesk_subscriptions_on_ticket_id"
  add_index "helpdesk_subscriptions", ["user_id"], :name => "index_helpdesk_subscriptions_on_user_id"

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
    t.integer  "ticket_type_id"
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
  end

  add_index "helpdesk_tickets", ["id_token"], :name => "index_helpdesk_tickets_on_id_token", :unique => true
  add_index "helpdesk_tickets", ["requester_id"], :name => "index_helpdesk_tickets_on_requester_id"
  add_index "helpdesk_tickets", ["responder_id"], :name => "index_helpdesk_tickets_on_responder_id"

  create_table "password_resets", :force => true do |t|
    t.string   "email"
    t.integer  "user_id"
    t.string   "remote_ip"
    t.string   "token"
    t.datetime "created_at"
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
  end

  add_index "users", ["account_id"], :name => "index_users_on_account_id"
  add_index "users", ["email"], :name => "index_users_on_email"
  add_index "users", ["perishable_token"], :name => "index_users_on_perishable_token"
  add_index "users", ["persistence_token"], :name => "index_users_on_persistence_token"
  add_index "users", ["single_access_token"], :name => "index_users_on_single_access_token", :unique => true

end
