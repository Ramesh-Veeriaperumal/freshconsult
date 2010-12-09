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

ActiveRecord::Schema.define(:version => 20101208150822) do

  create_table "accounts", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "full_domain"
    t.datetime "deleted_at"
    t.string   "default_email"
  end

  add_index "accounts", ["full_domain"], :name => "index_accounts_on_full_domain"

  create_table "forums", :force => true do |t|
    t.string  "name"
    t.string  "description"
    t.integer "topics_count",     :default => 0
    t.integer "posts_count",      :default => 0
    t.integer "position"
    t.text    "description_html"
    t.integer "account_id"
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
    t.integer  "priority"
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
  end

  add_index "posts", ["forum_id", "created_at"], :name => "index_posts_on_forum_id"
  add_index "posts", ["topic_id", "created_at"], :name => "index_posts_on_topic_id"
  add_index "posts", ["user_id", "created_at"], :name => "index_posts_on_user_id"

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
    t.integer  "posts_count",         :default => 0
    t.datetime "last_seen_at"
  end

  add_index "users", ["account_id"], :name => "index_users_on_account_id"
  add_index "users", ["email"], :name => "index_users_on_email"
  add_index "users", ["perishable_token"], :name => "index_users_on_perishable_token"
  add_index "users", ["persistence_token"], :name => "index_users_on_persistence_token"
  add_index "users", ["single_access_token"], :name => "index_users_on_single_access_token", :unique => true

end
