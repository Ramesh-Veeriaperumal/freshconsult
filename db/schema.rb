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

ActiveRecord::Schema.define(:version => 20150619065247) do

  create_table "account_additional_settings", :force => true do |t|
    t.string   "email_cmds_delimeter"
    t.integer  "account_id",           :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "ticket_id_delimiter",               :default => "#"
    t.boolean  "pass_through_enabled",              :default => true
    t.string   "bcc_email"
    t.text     "supported_languages"
    t.integer  "api_limit",                         :default => 1000
    t.integer  "date_format",                       :default => 1
    t.text     "additional_settings"
    t.text     "resource_rlimit_conf"
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

  add_index "admin_canned_responses", ["account_id", "folder_id", "title"], :name => "Index_ca_responses_on_account_id_folder_id_and_title", :length => {"account_id"=>nil, "folder_id"=>nil, "title"=>20}

  create_table "admin_data_imports", :force => true do |t|
    t.string   "import_type"
    t.boolean  "status"
    t.integer  "account_id",  :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "source"
  end

  add_index "admin_data_imports", ["account_id", "created_at"], :name => "index_data_imports_on_account_id_and_created_at"

  create_table "admin_user_accesses", :force => true do |t|
    t.string   "accessible_type"
    t.integer  "accessible_id",   :limit => 8
    t.integer  "user_id",         :limit => 8
    t.integer  "visibility",      :limit => 8
    t.integer  "group_id",        :limit => 8
    t.integer  "account_id",      :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "admin_user_accesses", ["account_id", "accessible_id", "accessible_type"], :name => "index_admin_acc_id_type"
  add_index "admin_user_accesses", ["account_id", "accessible_type", "accessible_id"], :name => "index_admin_user_accesses_on_account_id_and_acc_type_and_acc_id"
  add_index "admin_user_accesses", ["user_id"], :name => "index_admin_user_accesses_on_user_id"

  create_table "admin_users", :force => true do |t|
    t.string   "name"
    t.string   "password_salt"
    t.string   "crypted_password"
    t.string   "email"
    t.string   "perishable_token"
    t.string   "persistence_token"
    t.integer  "role"
    t.boolean  "active"
    t.datetime "last_request_at"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "affiliate_discount_mappings", :id => false, :force => true do |t|
    t.integer "subscription_affiliate_id", :limit => 8
    t.integer "affiliate_discount_id",     :limit => 8
  end

  create_table "affiliate_discounts", :force => true do |t|
    t.string  "code"
    t.string  "description"
    t.integer "discount_type"
  end

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
    t.datetime "active_since"
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
    t.integer "account_id",       :limit => 8
    t.string  "application_type",              :default => "freshplug", :null => false
  end

  create_table "article_tickets", :force => true do |t|
    t.integer "article_id", :limit => 8
    t.integer "ticket_id",  :limit => 8
    t.integer "account_id", :limit => 8
  end

  add_index "article_tickets", ["account_id"], :name => "index_article_tickets_on_account_id"
  add_index "article_tickets", ["article_id"], :name => "index_article_tickets_on_article_id"

  create_table "authorizations", :force => true do |t|
    t.string   "provider"
    t.string   "uid"
    t.integer  "user_id",    :limit => 8
    t.integer  "account_id", :limit => 8
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
    t.integer  "folder_type"
    t.boolean  "deleted",      :default => false
  end

  add_index "ca_folders", ["account_id","folder_type"], :name => "index_ca_folders_on_account_id_folder_type"

  create_table "chat_settings", :force => true do |t|
    t.integer  "account_id",      :limit => 8
    t.string   "display_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "active",                                :default => false
  end

  add_index "chat_settings", ["account_id"], :name => "index_chat_settings_on_account_id"

  create_table "chat_widgets", :force => true do |t|
    t.string   "name"
    t.integer  "account_id",            :limit => 8
    t.integer  "product_id",            :limit => 8
    t.string   "widget_id"
    t.boolean  "show_on_portal"
    t.boolean  "portal_login_required"
    t.integer  "business_calendar_id",  :limit => 8
    t.integer  "chat_setting_id",       :limit => 8
    t.boolean  "active",                             :default => false
    t.boolean  "main_widget"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name"
  end

  add_index "chat_widgets", ["account_id", "widget_id"], :name => "account_id_and_widget_id"

  create_table "company_field_choices", :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.integer  "company_field_id", :limit => 8
    t.string   "value"
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "company_field_choices", ["account_id", "company_field_id", "position"], :name => "idx_cf_choices_on_account_id_and_company_field_id_and_position"

  create_table "company_field_data", :force => true do |t|
    t.integer  "id",                  :limit => 8,                    :null => false
    t.integer  "account_id",          :limit => 8, :default => 0,     :null => false
    t.integer  "company_form_id",     :limit => 8
    t.integer  "company_id",          :limit => 8
    t.integer  "health"
    t.string   "priority"
    t.string   "company_external_id"
    t.string   "cf_str01"
    t.string   "cf_str02"
    t.string   "cf_str03"
    t.string   "cf_str04"
    t.string   "cf_str05"
    t.string   "cf_str06"
    t.string   "cf_str07"
    t.string   "cf_str08"
    t.string   "cf_str09"
    t.string   "cf_str10"
    t.string   "cf_str11"
    t.string   "cf_str12"
    t.string   "cf_str13"
    t.string   "cf_str14"
    t.string   "cf_str15"
    t.string   "cf_str16"
    t.string   "cf_str17"
    t.string   "cf_str18"
    t.string   "cf_str19"
    t.string   "cf_str20"
    t.string   "cf_str21"
    t.string   "cf_str22"
    t.string   "cf_str23"
    t.string   "cf_str24"
    t.string   "cf_str25"
    t.string   "cf_str26"
    t.string   "cf_str27"
    t.string   "cf_str28"
    t.string   "cf_str29"
    t.string   "cf_str30"
    t.string   "cf_str31"
    t.string   "cf_str32"
    t.string   "cf_str33"
    t.string   "cf_str34"
    t.string   "cf_str35"
    t.string   "cf_str36"
    t.string   "cf_str37"
    t.string   "cf_str38"
    t.string   "cf_str39"
    t.string   "cf_str40"
    t.string   "cf_str41"
    t.string   "cf_str42"
    t.string   "cf_str43"
    t.string   "cf_str44"
    t.string   "cf_str45"
    t.string   "cf_str46"
    t.string   "cf_str47"
    t.string   "cf_str48"
    t.string   "cf_str49"
    t.string   "cf_str50"
    t.string   "cf_str51"
    t.string   "cf_str52"
    t.string   "cf_str53"
    t.string   "cf_str54"
    t.string   "cf_str55"
    t.string   "cf_str56"
    t.string   "cf_str57"
    t.string   "cf_str58"
    t.string   "cf_str59"
    t.string   "cf_str60"
    t.string   "cf_str61"
    t.string   "cf_str62"
    t.string   "cf_str63"
    t.string   "cf_str64"
    t.string   "cf_str65"
    t.string   "cf_str66"
    t.string   "cf_str67"
    t.string   "cf_str68"
    t.string   "cf_str69"
    t.string   "cf_str70"
    t.string   "cf_str71"
    t.string   "cf_str72"
    t.string   "cf_str73"
    t.string   "cf_str74"
    t.string   "cf_str75"
    t.string   "cf_str76"
    t.text     "cf_text01"
    t.text     "cf_text02"
    t.text     "cf_text03"
    t.text     "cf_text04"
    t.text     "cf_text05"
    t.text     "cf_text06"
    t.text     "cf_text07"
    t.text     "cf_text08"
    t.text     "cf_text09"
    t.text     "cf_text10"
    t.integer  "cf_int01",            :limit => 8
    t.integer  "cf_int02",            :limit => 8
    t.integer  "cf_int03",            :limit => 8
    t.integer  "cf_int04",            :limit => 8
    t.integer  "cf_int05",            :limit => 8
    t.integer  "cf_int06",            :limit => 8
    t.integer  "cf_int07",            :limit => 8
    t.integer  "cf_int08",            :limit => 8
    t.integer  "cf_int09",            :limit => 8
    t.integer  "cf_int10",            :limit => 8
    t.integer  "cf_int11",            :limit => 8
    t.integer  "cf_int12",            :limit => 8
    t.integer  "cf_int13",            :limit => 8
    t.integer  "cf_int14",            :limit => 8
    t.integer  "cf_int15",            :limit => 8
    t.integer  "cf_int16",            :limit => 8
    t.integer  "cf_int17",            :limit => 8
    t.integer  "cf_int18",            :limit => 8
    t.integer  "cf_int19",            :limit => 8
    t.integer  "cf_int20",            :limit => 8
    t.datetime "cf_date01"
    t.datetime "cf_date02"
    t.datetime "cf_date03"
    t.datetime "cf_date04"
    t.datetime "cf_date05"
    t.datetime "cf_date06"
    t.datetime "cf_date07"
    t.datetime "cf_date08"
    t.datetime "cf_date09"
    t.datetime "cf_date10"
    t.boolean  "cf_boolean01"
    t.boolean  "cf_boolean02"
    t.boolean  "cf_boolean03"
    t.boolean  "cf_boolean04"
    t.boolean  "cf_boolean05"
    t.boolean  "cf_boolean06"
    t.boolean  "cf_boolean07"
    t.boolean  "cf_boolean08"
    t.boolean  "cf_boolean09"
    t.boolean  "cf_boolean10"
    t.decimal  "cf_decimal01",        :precision => 15, :scale => 4
    t.decimal  "cf_decimal02",        :precision => 15, :scale => 4
    t.decimal  "cf_decimal03",        :precision => 15, :scale => 4
    t.decimal  "cf_decimal04",        :precision => 15, :scale => 4
    t.decimal  "cf_decimal05",        :precision => 15, :scale => 4
    t.decimal  "cf_decimal06",        :precision => 15, :scale => 4
    t.decimal  "cf_decimal07",        :precision => 15, :scale => 4
    t.decimal  "cf_decimal08",        :precision => 15, :scale => 4
    t.decimal  "cf_decimal09",        :precision => 15, :scale => 4
    t.decimal  "cf_decimal10",        :precision => 15, :scale => 4
    t.integer  "long_cc01",           :limit => 8
    t.integer  "long_cc02",           :limit => 8
    t.integer  "long_cc03",           :limit => 8
    t.integer  "long_cc04",           :limit => 8
    t.integer  "long_cc05",           :limit => 8
    t.integer  "int_cc01"
    t.integer  "int_cc02"
    t.integer  "int_cc03"
    t.integer  "int_cc04"
    t.integer  "int_cc05"
    t.string   "string_cc01"
    t.string   "string_cc02"
    t.string   "string_cc03"
    t.string   "string_cc04"
    t.string   "string_cc05"
    t.string   "string_cc06"
    t.datetime "datetime_cc01"
    t.datetime "datetime_cc02"
    t.boolean  "boolean_cc01",        :default => false
    t.boolean  "boolean_cc02",        :default => false
    t.boolean  "boolean_cc03",        :default => false
    t.boolean  "boolean_cc04",        :default => false
    t.boolean  "boolean_cc05",        :default => false
    t.text     "text_cc01"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "company_field_data", ["account_id", "company_external_id"], :name => "index_company_field_data_on_account_id_and_company_external_id", :length => {"account_id"=>nil, "company_external_id"=>30}
  add_index "company_field_data", ["account_id", "company_form_id"], :name => "index_company_field_data_on_account_id_and_company_form_id"
  add_index "company_field_data", ["account_id", "company_id"], :name => "index_company_field_data_on_account_id_and_company_id"
  add_index "company_field_data", ["account_id", "int_cc01"], :name => "index_company_field_data_on_account_id_and_int_cc01"
  add_index "company_field_data", ["account_id", "long_cc01"], :name => "index_company_field_data_on_account_id_and_long_cc01"
  add_index "company_field_data", ["account_id", "priority"], :name => "index_company_field_data_on_account_id_and_priority", :length => {"account_id"=>nil, "priority"=>20}
  add_index "company_field_data", ["id"], :name => "index_company_field_data_id"

  create_table "company_fields", :force => true do |t|
    t.integer  "account_id",         :limit => 8
    t.integer  "company_form_id",    :limit => 8
    t.string   "name"
    t.string   "column_name"
    t.string   "label"
    t.integer  "field_type"
    t.integer  "position"
    t.boolean  "deleted",                         :default => false
    t.boolean  "required_for_agent",              :default => false
    t.text     "field_options"
    t.datetime "created_at"
    t.datetime "updated_at"
  end
  
  add_index "company_fields", ["account_id", "company_form_id", "field_type"], :name => "idx_company_field_account_id_and_company_form_id_and_field_type"
  add_index "company_fields", ["account_id", "company_form_id", "name"], :name => "index_company_fields_on_account_id_and_company_form_id_and_name", :length => {"account_id"=>nil, "company_form_id"=>nil, "name"=>20}
  add_index "company_fields", ["account_id", "company_form_id", "position"], :name => "idx_company_field_account_id_and_company_form_id_and_position"

  create_table "company_forms", :force => true do |t|
    t.integer  "account_id",   :limit => 8
    t.integer  "parent_id",    :limit => 8
    t.boolean  "active",                    :default => false
    t.text     "form_options"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "company_forms", ["account_id", "active", "parent_id"], :name => "index_company_forms_on_account_id_and_active_and_parent_id"

  create_table "contact_field_choices", :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.integer  "contact_field_id", :limit => 8
    t.string   "value"
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "contact_field_choices", ["account_id", "contact_field_id", "position"], :name => "idx_cf_choices_on_account_id_and_contact_field_id_and_position"

  create_table "contact_field_data", :force => true do |t|
    t.integer  "id",               :limit => 8,                                                   :null => false
    t.integer  "account_id",       :limit => 8,                                :default => 0,     :null => false
    t.integer  "contact_form_id",  :limit => 8
    t.integer  "user_id",          :limit => 8
    t.integer  "health"
    t.string   "priority"
    t.string   "user_external_id"
    t.string   "cf_str01"
    t.string   "cf_str02"
    t.string   "cf_str03"
    t.string   "cf_str04"
    t.string   "cf_str05"
    t.string   "cf_str06"
    t.string   "cf_str07"
    t.string   "cf_str08"
    t.string   "cf_str09"
    t.string   "cf_str10"
    t.string   "cf_str11"
    t.string   "cf_str12"
    t.string   "cf_str13"
    t.string   "cf_str14"
    t.string   "cf_str15"
    t.string   "cf_str16"
    t.string   "cf_str17"
    t.string   "cf_str18"
    t.string   "cf_str19"
    t.string   "cf_str20"
    t.string   "cf_str21"
    t.string   "cf_str22"
    t.string   "cf_str23"
    t.string   "cf_str24"
    t.string   "cf_str25"
    t.string   "cf_str26"
    t.string   "cf_str27"
    t.string   "cf_str28"
    t.string   "cf_str29"
    t.string   "cf_str30"
    t.string   "cf_str31"
    t.string   "cf_str32"
    t.string   "cf_str33"
    t.string   "cf_str34"
    t.string   "cf_str35"
    t.string   "cf_str36"
    t.string   "cf_str37"
    t.string   "cf_str38"
    t.string   "cf_str39"
    t.string   "cf_str40"
    t.string   "cf_str41"
    t.string   "cf_str42"
    t.string   "cf_str43"
    t.string   "cf_str44"
    t.string   "cf_str45"
    t.string   "cf_str46"
    t.string   "cf_str47"
    t.string   "cf_str48"
    t.string   "cf_str49"
    t.string   "cf_str50"
    t.string   "cf_str51"
    t.string   "cf_str52"
    t.string   "cf_str53"
    t.string   "cf_str54"
    t.string   "cf_str55"
    t.string   "cf_str56"
    t.string   "cf_str57"
    t.string   "cf_str58"
    t.string   "cf_str59"
    t.string   "cf_str60"
    t.string   "cf_str61"
    t.string   "cf_str62"
    t.string   "cf_str63"
    t.string   "cf_str64"
    t.string   "cf_str65"
    t.string   "cf_str66"
    t.string   "cf_str67"
    t.string   "cf_str68"
    t.string   "cf_str69"
    t.string   "cf_str70"
    t.string   "cf_str71"
    t.string   "cf_str72"
    t.string   "cf_str73"
    t.string   "cf_str74"
    t.string   "cf_str75"
    t.string   "cf_str76"
    t.text     "cf_text01"
    t.text     "cf_text02"
    t.text     "cf_text03"
    t.text     "cf_text04"
    t.text     "cf_text05"
    t.text     "cf_text06"
    t.text     "cf_text07"
    t.text     "cf_text08"
    t.text     "cf_text09"
    t.text     "cf_text10"
    t.integer  "cf_int01",         :limit => 8
    t.integer  "cf_int02",         :limit => 8
    t.integer  "cf_int03",         :limit => 8
    t.integer  "cf_int04",         :limit => 8
    t.integer  "cf_int05",         :limit => 8
    t.integer  "cf_int06",         :limit => 8
    t.integer  "cf_int07",         :limit => 8
    t.integer  "cf_int08",         :limit => 8
    t.integer  "cf_int09",         :limit => 8
    t.integer  "cf_int10",         :limit => 8
    t.integer  "cf_int11",         :limit => 8
    t.integer  "cf_int12",         :limit => 8
    t.integer  "cf_int13",         :limit => 8
    t.integer  "cf_int14",         :limit => 8
    t.integer  "cf_int15",         :limit => 8
    t.integer  "cf_int16",         :limit => 8
    t.integer  "cf_int17",         :limit => 8
    t.integer  "cf_int18",         :limit => 8
    t.integer  "cf_int19",         :limit => 8
    t.integer  "cf_int20",         :limit => 8
    t.datetime "cf_date01"
    t.datetime "cf_date02"
    t.datetime "cf_date03"
    t.datetime "cf_date04"
    t.datetime "cf_date05"
    t.datetime "cf_date06"
    t.datetime "cf_date07"
    t.datetime "cf_date08"
    t.datetime "cf_date09"
    t.datetime "cf_date10"
    t.boolean  "cf_boolean01"
    t.boolean  "cf_boolean02"
    t.boolean  "cf_boolean03"
    t.boolean  "cf_boolean04"
    t.boolean  "cf_boolean05"
    t.boolean  "cf_boolean06"
    t.boolean  "cf_boolean07"
    t.boolean  "cf_boolean08"
    t.boolean  "cf_boolean09"
    t.boolean  "cf_boolean10"
    t.decimal  "cf_decimal01",                  :precision => 15, :scale => 4
    t.decimal  "cf_decimal02",                  :precision => 15, :scale => 4
    t.decimal  "cf_decimal03",                  :precision => 15, :scale => 4
    t.decimal  "cf_decimal04",                  :precision => 15, :scale => 4
    t.decimal  "cf_decimal05",                  :precision => 15, :scale => 4
    t.decimal  "cf_decimal06",                  :precision => 15, :scale => 4
    t.decimal  "cf_decimal07",                  :precision => 15, :scale => 4
    t.decimal  "cf_decimal08",                  :precision => 15, :scale => 4
    t.decimal  "cf_decimal09",                  :precision => 15, :scale => 4
    t.decimal  "cf_decimal10",                  :precision => 15, :scale => 4
    t.integer  "long_uc01",        :limit => 8
    t.integer  "long_uc02",        :limit => 8
    t.integer  "long_uc03",        :limit => 8
    t.integer  "long_uc04",        :limit => 8
    t.integer  "long_uc05",        :limit => 8
    t.integer  "int_uc01"
    t.integer  "int_uc02"
    t.integer  "int_uc03"
    t.integer  "int_uc04"
    t.integer  "int_uc05"
    t.string   "string_uc07"
    t.string   "string_uc08"
    t.string   "string_uc09"
    t.string   "string_uc10"
    t.string   "string_uc11"
    t.string   "string_uc12"
    t.datetime "datetime_uc01"
    t.datetime "datetime_uc02"
    t.boolean  "boolean_uc01",                                                 :default => false
    t.boolean  "boolean_uc02",                                                 :default => false
    t.boolean  "boolean_uc03",                                                 :default => false
    t.boolean  "boolean_uc04",                                                 :default => false
    t.boolean  "boolean_uc05",                                                 :default => false
    t.text     "text_uc02"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "contact_field_data", ["account_id", "contact_form_id"], :name => "index_contact_field_data_on_account_id_and_contact_form_id"
  add_index "contact_field_data", ["account_id", "int_uc01"], :name => "index_contact_field_data_on_account_id_and_int_uc01"
  add_index "contact_field_data", ["account_id", "long_uc01"], :name => "index_contact_field_data_on_account_id_and_long_uc01"
  add_index "contact_field_data", ["account_id", "priority"], :name => "index_contact_field_data_on_account_id_and_priority", :length => {"account_id"=>nil, "priority"=>20}
  add_index "contact_field_data", ["account_id", "user_external_id"], :name => "index_contact_field_data_on_account_id_and_user_external_id", :length => {"account_id"=>nil, "user_external_id"=>30}
  add_index "contact_field_data", ["account_id", "user_id"], :name => "index_contact_field_data_on_account_id_and_user_id"
  add_index "contact_field_data", ["id"], :name => "index_contact_field_data_id"

  create_table "contact_fields", :force => true do |t|
    t.integer  "account_id",         :limit => 8
    t.integer  "contact_form_id",    :limit => 8
    t.string   "name"
    t.string   "column_name"
    t.string   "label"
    t.string   "label_in_portal"
    t.integer  "field_type"
    t.integer  "position"
    t.boolean  "deleted",                         :default => false
    t.boolean  "required_for_agent",              :default => false
    t.boolean  "visible_in_portal",               :default => false
    t.boolean  "editable_in_portal",              :default => false
    t.boolean  "editable_in_signup",              :default => false
    t.boolean  "required_in_portal",              :default => false
    t.text     "field_options"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "contact_fields", ["account_id", "contact_form_id", "field_type"], :name => "idx_contact_field_account_id_and_contact_form_id_and_field_type"
  add_index "contact_fields", ["account_id", "contact_form_id", "name"], :name => "index_contact_fields_on_account_id_and_contact_form_id_and_name", :length => {"account_id"=>nil, "contact_form_id"=>nil, "name"=>20}
  add_index "contact_fields", ["account_id", "contact_form_id", "position"], :name => "idx_contact_field_account_id_and_contact_form_id_and_position"

  create_table "contact_forms", :force => true do |t|
    t.integer  "account_id",   :limit => 8
    t.integer  "parent_id",    :limit => 8
    t.boolean  "active",                    :default => false
    t.text     "form_options"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "contact_forms", ["account_id", "active", "parent_id"], :name => "index_contact_forms_on_account_id_and_active_and_parent_id"

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
    t.integer  "account_id", :limit => 8
    t.integer  "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "source",                  :default => 1
    t.integer  "user_id",    :limit => 8
    t.string   "token"
    t.text     "last_error"
  end

  add_index "data_exports", ["account_id", "source", "token"], :name => "index_data_exports_on_account_id_source_and_token"
  add_index "data_exports", ["account_id", "user_id", "source"], :name => "index_data_exports_on_account_id_user_id_and_source"

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

  add_index "day_pass_usages", ["account_id", "user_id"], :name => "index_day_pass_usages_on_account_id_and_user_id"

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
    t.string   "pod_info",   :default => 'poduseast1', :null => false
  end

  add_index "delayed_jobs", ["locked_by"], :name => "index_delayed_jobs_on_locked_by"
  add_index "delayed_jobs", ["pod_info"], :name => "index_delayed_jobs_on_pod_info"

  create_table "deleted_customers", :force => true do |t|
    t.string   "full_domain"
    t.integer  "account_id",   :limit => 8
    t.string   "admin_name"
    t.string   "admin_email"
    t.text     "account_info"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "status",                    :default => 0
  end

  create_table "domain_mappings", :force => true do |t|
    t.integer "account_id", :limit => 8, :null => false
    t.integer "portal_id",  :limit => 8
    t.string  "domain",                  :null => false
  end

  add_index "domain_mappings", ["account_id", "portal_id"], :name => "index_domain_mappings_on_account_id_and_portal_id", :unique => true
  add_index "domain_mappings", ["domain"], :name => "index_domain_mappings_on_domain", :unique => true

  create_table "dynamic_notification_templates", :force => true do |t|
    t.integer  "account_id",            :limit => 8
    t.integer  "email_notification_id", :limit => 8
    t.integer  "category"
    t.integer  "language"
    t.text     "description"
    t.text     "subject"
    t.boolean  "outdated"
    t.boolean  "active"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

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
    t.boolean  "outdated_requester_content",              :default => false
    t.boolean  "outdated_agent_content",                  :default => false
  end

  add_index "email_notifications", ["account_id", "notification_type"], :name => "index_email_notifications_on_notification_type", :unique => true

  create_table "es_enabled_accounts", :force => true do |t|
    t.integer  "account_id", :limit => 8
    t.boolean  "imported",                :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "es_enabled_accounts", ["account_id"], :name => "index_es_enabled_accounts_on_account_id"

  create_table "facebook_page_mappings", :primary_key => "facebook_page_id", :force => true do |t|
    t.integer "account_id", :limit => 8, :null => false
  end

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
    t.string   "name",                                               :null => false
    t.integer  "account_id",          :limit => 8
    t.string   "module"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "product_id",          :limit => 8
    t.boolean  "active",                           :default => true
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
    t.integer  "ff_int01",            :limit => 8
    t.integer  "ff_int02",            :limit => 8
    t.integer  "ff_int03",            :limit => 8
    t.integer  "ff_int04",            :limit => 8
    t.integer  "ff_int05",            :limit => 8
    t.integer  "ff_int06",            :limit => 8
    t.integer  "ff_int07",            :limit => 8
    t.integer  "ff_int08",            :limit => 8
    t.integer  "ff_int09",            :limit => 8
    t.integer  "ff_int10",            :limit => 8
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
    t.integer  "ff_int11",            :limit => 8
    t.integer  "ff_int12",            :limit => 8
    t.integer  "ff_int13",            :limit => 8
    t.integer  "ff_int14",            :limit => 8
    t.integer  "ff_int15",            :limit => 8
    t.integer  "ff_int16",            :limit => 8
    t.integer  "ff_int17",            :limit => 8
    t.integer  "ff_int18",            :limit => 8
    t.integer  "ff_int19",            :limit => 8
    t.integer  "ff_int20",            :limit => 8
    t.string   "ffs_31"
    t.string   "ffs_32"
    t.string   "ffs_33"
    t.string   "ffs_34"
    t.string   "ffs_35"
    t.string   "ffs_36"
    t.string   "ffs_37"
    t.string   "ffs_38"
    t.string   "ffs_39"
    t.string   "ffs_40"
    t.string   "ffs_41"
    t.string   "ffs_42"
    t.string   "ffs_43"
    t.string   "ffs_44"
    t.string   "ffs_45"
    t.string   "ffs_46"
    t.string   "ffs_47"
    t.string   "ffs_48"
    t.string   "ffs_49"
    t.string   "ffs_50"
    t.string   "ffs_51"
    t.string   "ffs_52"
    t.string   "ffs_53"
    t.string   "ffs_54"
    t.string   "ffs_55"
    t.string   "ffs_56"
    t.string   "ffs_57"
    t.string   "ffs_58"
    t.string   "ffs_59"
    t.string   "ffs_60"
    t.string   "ffs_61"
    t.string   "ffs_62"
    t.string   "ffs_63"
    t.string   "ffs_64"
    t.string   "ffs_65"
    t.string   "ffs_66"
    t.string   "ffs_67"
    t.string   "ffs_68"
    t.string   "ffs_69"
    t.string   "ffs_70"
    t.string   "ffs_71"
    t.string   "ffs_72"
    t.string   "ffs_73"
    t.string   "ffs_74"
    t.string   "ffs_75"
    t.string   "ffs_76"
    t.string   "ffs_77"
    t.string   "ffs_78"
    t.string   "ffs_79"
    t.string   "ffs_80"
    t.decimal  "ff_decimal01",                     :precision => 10, :scale => 2
    t.decimal  "ff_decimal02",                     :precision => 10, :scale => 2
    t.decimal  "ff_decimal03",                     :precision => 10, :scale => 2
    t.decimal  "ff_decimal04",                     :precision => 10, :scale => 2
    t.decimal  "ff_decimal05",                     :precision => 10, :scale => 2
    t.decimal  "ff_decimal06",                     :precision => 10, :scale => 2
    t.decimal  "ff_decimal07",                     :precision => 10, :scale => 2
    t.decimal  "ff_decimal08",                     :precision => 10, :scale => 2
    t.decimal  "ff_decimal09",                     :precision => 10, :scale => 2
    t.decimal  "ff_decimal10",                     :precision => 10, :scale => 2
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

  create_table "forum_moderators", :force => true do |t|
    t.integer "account_id",   :limit => 8
    t.integer "moderator_id", :limit => 8
  end

  add_index "forum_moderators", ["account_id", "moderator_id"], :name => "index_forum_moderators_on_account_id_and_moderator_id", :unique => true

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

  create_table "freshfone_accounts", :force => true do |t|
    t.integer  "account_id",              :limit => 8
    t.string   "friendly_name"
    t.string   "twilio_subaccount_id"
    t.string   "twilio_subaccount_token"
    t.string   "twilio_application_id"
    t.integer  "state",                   :limit => 1, :default => 1
    t.boolean  "deleted",                              :default => false
    t.string   "queue"
    t.datetime "expires_on"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "twilio_client_version",   :limit => 10, :default => "1.2"
    t.boolean  "security_whitelist",                         :default => false
    t.text     "triggers"
  end

  add_index "freshfone_accounts", ["account_id", "state", "expires_on"], :name => "index_freshfone_accounts_on_account_id_and_state_and_expires_on"
  add_index "freshfone_accounts", ["account_id"], :name => "index_freshfone_accounts_on_account_id", :unique => true

  create_table "freshfone_blacklist_numbers", :force => true do |t|
    t.integer  "account_id", :limit => 8
    t.string   "number",     :limit => 50
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "freshfone_blacklist_numbers", ["account_id", "number"], :name => "index_freshfone_blacklist_numbers_on_account_id_and_number"

  create_table "freshfone_callers", :force => true do |t|
    t.integer  "account_id", :limit => 8
    t.string   "number",     :limit => 50
    t.string   "country"
    t.string   "state"
    t.string   "city"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "caller_type", :limit => 1,  :default => 0
  end

  add_index "freshfone_callers", ["id", "account_id"], :name => "index_freshfone_callers_on_id_and_account_id", :unique => true
  add_index "freshfone_callers", ["account_id", "number"], :name => "index_ff_callers_on_account_id_and_number"

  create_table "freshfone_calls", :id => false, :force => true do |t|
    t.integer  "id",                  :limit => 8,                 :null => false
    t.integer  "account_id",          :limit => 8,                 :null => false
    t.integer  "freshfone_number_id", :limit => 8,                 :null => false
    t.integer  "user_id",             :limit => 8
    t.integer  "customer_id",         :limit => 8
    t.string   "call_sid",            :limit => 50
    t.string   "dial_call_sid",       :limit => 50
    t.integer  "call_status",                       :default => 0
    t.integer  "call_type",                         :default => 0
    t.integer  "call_duration"
    t.string   "recording_url"
    t.integer  "caller_number_id",    :limit => 8
    t.float    "call_cost"
    t.string   "currency",            :limit => 20, :default => "USD"
    t.string   "ancestry"
    t.integer  "children_count",                    :default => 0
    t.integer  "notable_id",          :limit => 8
    t.string   "notable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "direct_dial_number"
    t.integer  "group_id",            :limit => 8
    t.boolean  "recording_deleted",                     :default => false
    t.text     "recording_deleted_info"
  end

  add_index "freshfone_calls", ["account_id", "ancestry"], :name => "index_freshfone_calls_on_account_id_and_ancestry", :length => {"account_id"=>nil, "ancestry"=>12}
  add_index "freshfone_calls", ["account_id", "call_sid"], :name => "index_freshfone_calls_on_account_id_and_call_sid"
  add_index "freshfone_calls", ["account_id", "created_at"], :name => "index_freshfone_calls_on_account_id_and_created_at"
  add_index "freshfone_calls", ["account_id", "call_status", "user_id"], :name => "index_freshfone_calls_on_account_id_and_call_status_and_user"
  add_index "freshfone_calls", ["account_id", "customer_id", "created_at"], :name => "index_ff_calls_on_account_id_customer_id_created_at"
  add_index "freshfone_calls", ["account_id", "dial_call_sid"], :name => "index_freshfone_calls_on_account_id_and_dial_call_sid"
  add_index "freshfone_calls", ["account_id", "freshfone_number_id", "created_at"], :name => "index_ff_calls_on_account_ff_number_and_created"
  add_index "freshfone_calls", ["account_id", "notable_type", "notable_id"], :name => "index_ff_calls_on_account_id_notable_type_id"
  add_index "freshfone_calls", ["account_id", "updated_at"], :name => "index_freshfone_calls_on_account_id_and_updated_at"
  add_index "freshfone_calls", ["account_id", "user_id", "created_at", "ancestry"], :name => "index_ff_calls_on_account_user_ancestry_and_created_at"
  add_index "freshfone_calls", ["id", "account_id"], :name => "index_freshfone_calls_on_id_and_account_id", :unique => true
  add_index "freshfone_calls", ["id"], :name => "index_ff_calls_on_id"

  create_table "freshfone_credits", :force => true do |t|
    t.integer  "account_id",              :limit => 8
    t.decimal  "available_credit",                     :precision => 10, :scale => 4, :default => 0.0
    t.boolean  "auto_recharge",                                                       :default => false
    t.integer  "recharge_quantity"
    t.integer  "auto_recharge_threshold",                                             :default => 5
    t.decimal  "last_purchased_credit",                :precision => 6,  :scale => 2, :default => 0.0
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "freshfone_credits", ["account_id"], :name => "index_freshfone_credits_on_account_id"

  create_table "freshfone_ivrs", :force => true do |t|
    t.integer  "account_id",          :limit => 8,                   :null => false
    t.integer  "freshfone_number_id", :limit => 8,                   :null => false
    t.text     "ivr_data"
    t.text     "ivr_draft_data"
    t.boolean  "active",                           :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "welcome_message"
    t.integer  "message_type",                     :default => 0
  end

  add_index "freshfone_ivrs", ["account_id", "freshfone_number_id"], :name => "index_freshfone_ivrs_on_account_id_and_freshfone_number_id"

  create_table "freshfone_number_addresses", :force => true do |t|
    t.integer  "id",                   :limit => 8, :null => false
    t.integer  "account_id",           :limit => 8
    t.integer  "freshfone_account_id", :limit => 8
    t.string   "address_sid"
    t.string   "friendly_name"
    t.string   "business_name"
    t.string   "address"
    t.string   "city"
    t.string   "state"
    t.string   "postal_code"
    t.string   "country",              :limit => 5
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "freshfone_number_addresses", ["account_id", "country"], :name => "index_freshfone_number_address_on_account_id_and_country"
  add_index "freshfone_number_addresses", ["id", "account_id"], :name => "index_freshfone_number_address_on_id_and_account_id", :unique => true

  create_table "freshfone_number_groups", :force => true do |t|
    t.integer  "account_id",          :limit => 8
    t.integer  "freshfone_number_id", :limit => 8
    t.integer  "group_id",            :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "freshfone_number_groups", ["id", "account_id"], :name => "index_freshfone_number_groups_on_id_and_account_id", :unique => true

  create_table "freshfone_numbers", :force => true do |t|
    t.integer  "account_id",               :limit => 8
    t.string   "number",                   :limit => 50
    t.string   "display_number",           :limit => 50
    t.string   "region",                   :limit => 100,                               :default => ""
    t.string   "country",                  :limit => 20,                                :default => ""
    t.decimal  "rate",                                    :precision => 6, :scale => 2
    t.boolean  "record",                                                                :default => true
    t.integer  "queue_wait_time",                                                       :default => 2
    t.integer  "max_queue_length",                                                      :default => 3
    t.integer  "state",                    :limit => 1,                                 :default => 1
    t.string   "number_sid"
    t.integer  "number_type"
    t.integer  "voice",                                                                 :default => 0
    t.boolean  "deleted",                                                               :default => false
    t.text     "on_hold_message"
    t.text     "non_availability_message"
    t.text     "voicemail_message"
    t.integer  "business_calendar_id",     :limit => 8
    t.datetime "next_renewal_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "voicemail_active",                                                      :default => false
    t.text     "non_business_hours_message"
    t.string   "name"
    t.integer  "direct_dial_limit",                                                       :default => 1
    t.integer  "hunt_type",                                                               :default => 1
    t.integer  "rr_timeout",                                                            :default => 10
    t.integer  "ringing_time",                                                            :default => 30
    t.boolean  "recording_visibility",                                                    :default => true
  end

  add_index "freshfone_numbers", ["account_id", "number"], :name => "index_freshfone_numbers_on_account_id_and_number"
  add_index "freshfone_numbers", ["state", "next_renewal_at"], :name => "index_freshfone_numbers_on_state_and_next_renewal_at"

  create_table "freshfone_other_charges", :force => true do |t|
    t.integer  "account_id",          :limit => 8
    t.integer  "action_type"
    t.integer  "freshfone_number_id", :limit => 8
    t.float    "debit_payment"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "freshfone_other_charges", ["account_id"], :name => "index_freshfone_other_charges_on_account_id"

  create_table "freshfone_payments", :force => true do |t|
    t.integer  "account_id",       :limit => 8
    t.decimal  "purchased_credit",              :precision => 10, :scale => 4, :default => 0.0
    t.boolean  "status"
    t.string   "status_message"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "freshfone_payments", ["account_id"], :name => "index_freshfone_payments_on_account_id"

  create_table "freshfone_usage_triggers", :force => true do |t|
    t.integer  "account_id",           :limit => 8
    t.integer  "freshfone_account_id", :limit => 8
    t.integer  "trigger_type"
    t.string   "sid",                  :limit => 50
    t.integer  "start_value"
    t.integer  "trigger_value"
    t.integer  "fired_value"
    t.string   "idempotency_token",    :limit => 100
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "freshfone_usage_triggers", ["account_id", "created_at", "trigger_type"], :name => "index_ff_usage_triggers_account_created_at_type"
  add_index "freshfone_usage_triggers", ["account_id", "sid"], :name => "index_freshfone_usage_triggers_on_account_id_and_sid"

  create_table "freshfone_users", :force => true do |t|
    t.integer  "account_id",          :limit => 8,                    :null => false
    t.integer  "user_id",             :limit => 8,                    :null => false
    t.integer  "presence",                         :default => 0
    t.integer  "incoming_preference",              :default => 0
    t.boolean  "available_on_phone",               :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "mobile_token_refreshed_at"
    t.datetime "last_call_at"
    t.text     "capability_token_hash"
  end

  add_index "freshfone_users", ["account_id", "last_call_at"], :name => "index_ff_users_account_last_call"
  add_index "freshfone_users", ["account_id", "presence"], :name => "index_freshfone_users_on_account_id_and_presence"
  add_index "freshfone_users", ["account_id", "user_id"], :name => "index_freshfone_users_on_account_id_and_user_id", :unique => true

  create_table "freshfone_calls_meta", :force => true do |t|
    t.integer  "account_id", :limit => 8
    t.integer  "call_id",    :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "meta_info"
    t.integer  "device_type"
    t.integer  "transfer_by_agent", :limit => 8
  end

  add_index "freshfone_calls_meta", ["account_id", "call_id"], :name => "index_ff_calls_meta_on_account_id_call_id"
  add_index "freshfone_calls_meta", ["account_id", "device_type"], :name => "index_ff_calls_meta_on_account_id_device_type"
  add_index "freshfone_calls_meta", ["id", "account_id"], :name => "index_freshfone_calls_meta_on_id_and_account_id", :unique => true

 create_table "freshfone_whitelist_countries", :force => true do |t|
    t.integer "account_id", :limit => 8
    t.string  "country",    :limit => 50
 end

 add_index "freshfone_whitelist_countries", ["account_id", "country"], :name => "index_ff_whitelist_countries_on_account_id_and_country"
 

  create_table "global_blacklisted_ips", :force => true do |t|
    t.text     "ip_list"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

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

  add_index "google_contacts", ["account_id", "user_id"], :name => "index_google_contacts_on_accid_and_uid"

  create_table "google_domains", :primary_key => "account_id", :force => true do |t|
    t.string "domain", :null => false
  end

  add_index "google_domains", ["domain"], :name => "index_google_domains_on_domain", :unique => true


  create_table "group_accesses", :id => false, :force => true do |t|
    t.integer "group_id",   :limit => 8, :null => false
    t.integer "access_id",  :limit => 8, :null => false
    t.integer "account_id", :limit => 8, :null => false
  end

  add_index "group_accesses", ["access_id"], :name => "index_group_accesses_on_access_id"
  add_index "group_accesses", ["account_id"], :name => "index_group_accesses_on_account_id"
  add_index "group_accesses", ["group_id"], :name => "index_group_accesses_on_group_id"

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
    t.integer  "business_calendar_id", :limit => 8
  end

  add_index "groups", ["account_id", "name"], :name => "index_groups_on_account_id", :unique => true

  create_table "helpdesk_accesses", :force => true do |t|
    t.string   "accessible_type"
    t.integer  "accessible_id",   :limit => 8
    t.integer  "account_id",      :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "access_type",                  :default => 0
  end

  add_index "helpdesk_accesses", ["account_id", "accessible_type", "accessible_id"], :name => "index_helpdesk_accesses_on_accessibles"

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

  add_index "helpdesk_attachments", ["account_id", "attachable_id", "attachable_type"], :name => "index_helpdesk_attachments_on_attachable_id", :length => {"account_id"=>nil, "attachable_id"=>nil, "attachable_type"=>14}
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
    t.integer  "droppable_id",   :limit => 8
    t.string   "droppable_type"
    t.integer  "application_id", :limit => 8
    t.string   "filename"
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

  add_index "helpdesk_external_notes", ["account_id", "installed_application_id", "external_id"], :name => "index_helpdesk_external_id", :length => {"account_id"=>nil, "installed_application_id"=>nil, "external_id"=>20}
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
  add_index "helpdesk_schema_less_notes", ["account_id", "string_nc01"], :name => "index_helpdesk_schema_less_notes_on_account_id_string_nc01", :length => {"account_id"=>nil, "string_nc01"=>10}
  add_index "helpdesk_schema_less_notes", ["account_id", "string_nc02"], :name => "index_helpdesk_schema_less_notes_on_account_id_string_nc02", :length => {"account_id"=>nil, "string_nc02"=>10}
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
  add_index "helpdesk_schema_less_tickets", ["string_tc01", "account_id"], :name => "index_helpdesk_schema_less_tickets_on_ticket_id_and_string_01", :length => {"string_tc01"=>10, "account_id"=>nil}
  add_index "helpdesk_schema_less_tickets", ["string_tc02", "account_id"], :name => "index_helpdesk_schema_less_tickets_on_ticket_id_and_string_02", :length => {"string_tc02"=>10, "account_id"=>nil}
  add_index "helpdesk_schema_less_tickets", ["ticket_id", "account_id"], :name => "index_helpdesk_schema_less_tickets_on_account_id_ticket_id", :unique => true

  create_table "helpdesk_shared_attachments", :force => true do |t|
    t.string   "shared_attachable_type"
    t.integer  "shared_attachable_id",   :limit => 8
    t.integer  "attachment_id",          :limit => 8
    t.integer  "account_id",             :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "helpdesk_shared_attachments", ["account_id", "shared_attachable_id", "shared_attachable_type"], :name => "index_helpdesk_shared_attachments_on_attachable_id", :length => {"account_id"=>nil, "shared_attachable_id"=>nil, "shared_attachable_type"=>15}
  add_index "helpdesk_shared_attachments", ["account_id", "shared_attachable_id"], :name => "index_helpdesk_attachement_shared_id_share_id"

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
  add_index "helpdesk_tag_uses", ["taggable_id", "taggable_type"], :name => "helpdesk_tag_uses_taggable", :length => {"taggable_id"=>nil, "taggable_type"=>10}

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
    t.boolean  "default",                              :default => false
    t.integer  "level",                   :limit => 8
    t.integer  "parent_id",               :limit => 8
    t.string   "prefered_ff_col"
    t.integer  "import_id",               :limit => 8
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
  add_index "helpdesk_tickets", ["status", "account_id"], :name => "index_helpdesk_tickets_status_and_account_id"

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

  add_index "helpdesk_time_sheets", ["account_id", "workable_id", "workable_type"], :name => "index_helpdesk_sheets_on_workable_acc"
  add_index "helpdesk_time_sheets", ["account_id", "workable_type", "workable_id"], :name => "index_helpdesk_sheets_on_workable_account"
  add_index "helpdesk_time_sheets", ["account_id"], :name => "index_time_sheets_on_account_id_and_ticket_id"
  add_index "helpdesk_time_sheets", ["user_id"], :name => "index_time_sheets_on_user_id"
  add_index "helpdesk_time_sheets", ["workable_type", "workable_id"], :name => "index_helpdesk_sheets_on_workable"

  create_table "imap_mailboxes", :force => true do |t|
    t.integer  "email_config_id",    :limit => 8
    t.integer  "account_id",         :limit => 8
    t.string   "server_name"
    t.string   "user_name"
    t.text     "password"
    t.integer  "port"
    t.string   "authentication"
    t.boolean  "use_ssl"
    t.string   "folder"
    t.boolean  "delete_from_server"
    t.boolean  "enabled",                         :default => true
    t.integer  "timeout"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "imap_mailboxes", ["account_id", "email_config_id"], :name => "index_mailboxes_on_account_id_email_config_id"

  create_table "installed_applications", :force => true do |t|
    t.integer  "application_id", :limit => 8
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

  create_table "mailbox_jobs", :force => true do |t|
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
    t.string   "pod_info",   :default => 'poduseast1', :null => false
  end

  add_index "mailbox_jobs", ["locked_by"], :name => "index_mailbox_jobs_on_locked_by"
  add_index "mailbox_jobs", ["pod_info"], :name => "index_mailbox_jobs_on_pod_info"

  create_table "mobihelp_apps", :force => true do |t|
    t.integer  "account_id", :limit => 8, :null => false
    t.string   "name",                    :null => false
    t.integer  "platform",                :null => false
    t.string   "app_key",                 :null => false
    t.string   "app_secret",              :null => false
    t.text     "config"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "deleted",                 :default => false
  end

  add_index "mobihelp_apps", ["account_id", "app_key", "app_secret"], :name => "index_mobihelp_apps_on_account_id_and_app_key_and_app_secret", :unique => true
  add_index "mobihelp_apps", ["account_id", "name", "platform"], :name => "index_mobihelp_apps_on_account_id_and_name_and_platform"
  add_index "mobihelp_apps", ["account_id"], :name => "index_mobihelp_apps_on_account_id"

  create_table "mobihelp_devices", :force => true do |t|
    t.integer  "account_id",  :limit => 8, :null => false
    t.integer  "user_id",     :limit => 8, :null => false
    t.integer  "app_id",      :limit => 8, :null => false
    t.string   "device_uuid",              :null => false
    t.text     "info"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "mobihelp_devices", ["account_id", "app_id", "device_uuid"], :name => "index_mobihelp_devices_on_account_id_and_app_id_and_device_uuid", :unique => true
  add_index "mobihelp_devices", ["account_id", "user_id", "device_uuid"], :name => "index_mobihelp_devices_on_account_id_and_user_id_and_device_uuid"

  create_table "mobihelp_ticket_infos", :force => true do |t|
    t.integer  "account_id",   :limit => 8, :null => false
    t.integer  "ticket_id",    :limit => 8, :null => false
    t.integer  "device_id",    :limit => 8, :null => false
    t.text     "app_name",                  :null => false
    t.text     "app_version",               :null => false
    t.text     "os",                        :null => false
    t.text     "os_version",                :null => false
    t.text     "sdk_version",               :null => false
    t.text     "device_make",               :null => false
    t.text     "device_model",              :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "mobihelp_ticket_infos", ["account_id", "device_id"], :name => "index_mobihelp_ticket_infos_on_account_id_and_device_id"
  add_index "mobihelp_ticket_infos", ["account_id", "ticket_id"], :name => "index_mobihelp_ticket_infos_on_account_id_and_ticket_id", :unique => true

  create_table "mobihelp_app_solutions", :force => true do |t|
    t.integer  "account_id",  :limit => 8, :null => false
    t.integer  "app_id",      :limit => 8, :null => false
    t.integer  "category_id", :limit => 8, :null => false
    t.integer  "position",                 :null => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "solution_category_meta_id", :limit => 8
  end

  add_index "mobihelp_app_solutions", ["account_id", "app_id"], :name => "index_mobihelp_app_solutions_on_account_id_and_app_id"
  add_index "mobihelp_app_solutions", ["account_id", "category_id"], :name => "index_mobihelp_app_solutions_on_account_id_and_category_id"
  add_index "mobihelp_app_solutions", ["account_id", "solution_category_meta_id"], :name => "index_app_solutions_on_account_id_solution_category_meta_id"

  create_table "mobile_app_versions", :force => true do |t|
    t.integer  "mobile_type"
    t.string   "app_version"
    t.boolean  "supported"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "moderatorships", :force => true do |t|
    t.integer "forum_id", :limit => 8
    t.integer "user_id",  :limit => 8
  end

  add_index "moderatorships", ["forum_id"], :name => "index_moderatorships_on_forum_id"

  create_table "monitorships", :force => true do |t|
    t.integer "monitorable_id",   :limit => 8
    t.integer "user_id",          :limit => 8
    t.boolean "active",                        :default => true
    t.integer "account_id",       :limit => 8
    t.string  "monitorable_type"
    t.integer "portal_id",        :limit => 8
  end

  add_index "monitorships", ["account_id", "monitorable_id", "monitorable_type"], :name => "index_on_monitorships_acc_mon_id_and_type", :length => {"account_id"=>nil, "monitorable_id"=>nil, "monitorable_type"=>5}
  add_index "monitorships", ["account_id", "user_id", "monitorable_id", "monitorable_type"], :name => "complete_monitor_index"
  add_index "monitorships", ["user_id", "account_id"], :name => "index_for_monitorships_on_user_id_account_id"

  create_table "password_resets", :force => true do |t|
    t.string   "email"
    t.integer  "user_id",    :limit => 8
    t.string   "remote_ip"
    t.string   "token"
    t.datetime "created_at"
  end

  create_table "pod_shard_conditions", :force => true do |t|
    t.string "pod_info",   :null => false
    t.string "shard_name", :null => false
    t.string "query_type", :null => false
    t.text "accounts",   :null => false
  end

  add_index "pod_shard_conditions", ["pod_info", "shard_name"], :name => "index_pod_shard_conditions_on_pod_info_and_shard_name", :unique => true

  create_table "portal_forum_categories", :force => true do |t|
    t.integer "portal_id",         :limit => 8
    t.integer "forum_category_id", :limit => 8
    t.integer "account_id",        :limit => 8
    t.integer "position"
  end

  add_index "portal_forum_categories", ["account_id", "portal_id"], :name => "index_portal_forum_categories_on_account_id_and_portal_id"
  add_index "portal_forum_categories", ["portal_id", "forum_category_id"], :name => "index_portal_forum_categories_on_portal_id_and_forum_category_id"

  create_table "portal_pages", :force => true do |t|
    t.integer  "template_id", :limit => 8,        :null => false
    t.integer  "account_id",  :limit => 8,        :null => false
    t.integer  "page_type",                       :null => false
    t.text     "content",     :limit => 16777215
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "portal_pages", ["account_id", "template_id", "page_type"], :name => "index_portals_on_account_id_and_template_id_page_type"

  create_table "portal_solution_categories", :force => true do |t|
    t.integer "portal_id",            :limit => 8
    t.integer "solution_category_id", :limit => 8
    t.integer "account_id",           :limit => 8
    t.integer "position"
    t.integer "solution_category_meta_id", :limit => 8
  end

  add_index "portal_solution_categories", ["account_id", "portal_id"], :name => "index_portal_solution_categories_on_account_id_and_portal_id"
  add_index "portal_solution_categories", ["portal_id", "solution_category_id"], :name => "index_on_portal_and_soln_categ_id"
  add_index "portal_solution_categories", ["portal_id", "solution_category_meta_id"], :name => "index_portal_solution_categories_on_portal_id_category_meta_id"

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
    t.text     "head"
  end

  add_index "portal_templates", ["account_id", "portal_id"], :name => "index_portals_on_account_id_and_portal_id"

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
    t.boolean  "published",               :default => false
    t.boolean  "spam"
    t.boolean  "trash",                   :default => false
    t.integer  "user_votes",              :default => 0
  end

  add_index "posts", ["account_id", "created_at"], :name => "index_posts_on_account_id_and_created_at"
  add_index "posts", ["account_id", "trash"], :name => "index_posts_on_account_id_and_trash"
  add_index "posts", ["forum_id", "created_at"], :name => "index_posts_on_forum_id"
  add_index "posts", ["topic_id", "created_at"], :name => "index_posts_on_topic_id"
  add_index "posts", ["topic_id", "published"], :name => "index_posts_on_topic_id_and_published"
  add_index "posts", ["topic_id", "spam"], :name => "index_posts_on_topic_id_and_spam"
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
    t.integer  "category"
    t.integer  "sub_category"
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
    t.string  "pod_info",   :default => 'poduseast1', :null => false
    t.string  "region",     :default => 'us-east-1', :null => false
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

  create_table "smtp_mailboxes", :force => true do |t|
    t.integer  "email_config_id", :limit => 8
    t.integer  "account_id",      :limit => 8
    t.string   "server_name"
    t.string   "user_name"
    t.text     "password"
    t.integer  "port"
    t.string   "authentication"
    t.boolean  "use_ssl"
    t.boolean  "enabled",                      :default => true
    t.string   "domain"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "smtp_mailboxes", ["account_id", "email_config_id"], :name => "index_mailboxes_on_account_id_email_config_id"

   create_table "service_api_keys", :force => true do |t|
    t.string   "service_name", :null => false
    t.string   "api_key",      :null => false
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
   end

  add_index "service_api_keys", ["api_key"], :name => "index_service_api_keys_on_api_key", :unique => true
  add_index "service_api_keys", ["service_name"], :name => "index_service_api_keys_on_service_name", :unique => true

  create_table "social_facebook_pages", :force => true do |t|
    t.integer  "profile_id",            :limit => 8
    t.string   "access_token"
    t.integer  "page_id",               :limit => 8
    t.string   "page_name"
    t.string   "page_token"
    t.string   "page_img_url"
    t.string   "page_link"
    t.boolean  "import_visitor_posts",               :default => true
    t.boolean  "import_company_posts",               :default => false
    t.boolean  "enable_page",                        :default => false
    t.integer  "fetch_since",           :limit => 8
    t.integer  "product_id",            :limit => 8
    t.integer  "account_id",            :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "dm_thread_time",        :limit => 8, :default => 99999999999999999
    t.integer  "message_since",         :limit => 8, :default => 0
    t.boolean  "import_dms",                         :default => true
    t.boolean  "reauth_required",                    :default => false
    t.text     "last_error"
    t.boolean  "realtime_subscription",              :default => false,             :null => false
    t.string   "page_token_tab"
  end

  add_index "social_facebook_pages", ["account_id", "page_id"], :name => "index_pages_on_account_id"
  add_index "social_facebook_pages", ["page_id"], :name => "facebook_page_id", :unique => true
  add_index "social_facebook_pages", ["page_id"], :name => "index_page_id", :unique => true
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
    t.text     "post_attributes"
    t.string   "ancestry"
  end

  add_index "social_fb_posts", ["account_id", "postable_id", "postable_type"], :name => "index_social_fb_posts_account_id_postable_id_postable_type", :length => {"account_id"=>nil, "postable_id"=>nil, "postable_type"=>15}
  add_index "social_fb_posts", ["account_id", "ancestry"], :name => "account_ancestry_index", :length => {"account_id" => nil, "ancestry" => 30}
  add_index "social_fb_posts", ["account_id", "post_id"], :name => "index_social_fb_posts_on_post_id", :length => {"account_id" => nil, "post_id" => 30}

  create_table "social_streams", :force => true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "social_id",   :limit => 8
    t.integer  "account_id",  :limit => 8
    t.text     "includes"
    t.text     "excludes"
    t.text     "filter"
    t.text     "data"
    t.string   "type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "social_streams", ["account_id", "social_id"], :name => "index_social_streams_on_account_id_and_social_id"

  create_table "social_ticket_rules", :force => true do |t|
    t.integer  "rule_type"
    t.integer  "stream_id",   :limit => 8
    t.integer  "account_id",  :limit => 8
    t.text     "filter_data"
    t.text     "action_data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "position"
  end

  add_index "social_ticket_rules", ["account_id", "stream_id"], :name => "index_social_ticket_rules_on_account_id_and_stream_id"

  create_table "social_tweets", :force => true do |t|
    t.integer  "tweet_id",          :limit => 8
    t.integer  "tweetable_id",      :limit => 8
    t.string   "tweetable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id",        :limit => 8
    t.string   "tweet_type",                     :default => "mention"
    t.integer  "twitter_handle_id", :limit => 8
    t.integer  "stream_id",         :limit => 8
  end

  add_index "social_tweets", ["account_id", "stream_id"], :name => "index_social_tweets_on_stream_id"
  add_index "social_tweets", ["account_id", "tweet_id"], :name => "index_social_tweets_on_tweet_id"
  add_index "social_tweets", ["account_id", "tweetable_id", "tweetable_type"], :name => "index_social_tweets_account_id_tweetable_id_tweetable_type", :length => {"account_id"=>nil, "tweetable_id"=>nil, "tweetable_type"=>15}

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
    t.integer  "account_id",                :limit => 8
    t.text     "search_keys"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "dm_thread_time",                         :default => 0
    t.integer  "state",                                  :default => 1
    t.text     "last_error"
    t.text     "rule_value"
    t.text     "rule_tag"
    t.integer  "gnip_rule_state",                        :default => 0
  end

  add_index "social_twitter_handles", ["account_id", "twitter_user_id"], :name => "social_twitter_handle_product_id", :unique => true

  create_table "solution_article_bodies", :force => true do |t|
    t.integer  "account_id",   :limit => 8,          :null => false
    t.integer  "article_id",   :limit => 8,          :null => false
    t.text     "description",  :limit => 2147483647
    t.text     "desc_un_html", :limit => 2147483647
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "solution_article_bodies", ["account_id", "article_id"], :name => 'index_solution_article_bodies_on_account_id_and_article_id', :unique => true

  create_table "solution_article_meta", :force => true do |t|
    t.integer  "position"
    t.integer  "art_type"
    t.integer  "thumbs_up",                            :default => 0
    t.integer  "thumbs_down",                          :default => 0
    t.integer  "hits",                                 :default => 0
    t.integer  "solution_folder_meta_id", :limit => 8
    t.integer  "account_id",              :limit => 8,                :null => false
    t.datetime "created_at",                                          :null => false
    t.datetime "updated_at",                                          :null => false
  end

  add_index "solution_article_meta", ["account_id", "solution_folder_meta_id", "created_at"], :name => "index_article_meta_on_account_id_folder_meta_and_created_at"
  add_index "solution_article_meta", ["account_id", "solution_folder_meta_id", "position"], :name => "index_article_meta_on_account_id_folder_meta_and_position"

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
    t.datetime "modified_at"
    t.integer  "hits",                               :default => 0
    t.integer  "language_id"
    t.integer  "parent_id",    :limit => 8
    t.boolean  "outdated",                           :default => false
    t.integer  "modified_by",  :limit => 8
    t.integer  "int_01",       :limit => 8
    t.integer  "int_02",       :limit => 8
    t.integer  "int_03",       :limit => 8
    t.boolean  "bool_01"
    t.datetime "datetime_01"
    t.string   "string_01"
    t.string   "string_02"
  end

  add_index "solution_articles", ["account_id", "folder_id", "created_at"], :name => "index_solution_articles_on_acc_folder_created_at"
  add_index "solution_articles", ["account_id", "folder_id", "position"], :name => "index_solution_articles_on_account_id_and_folder_id_and_position"
  add_index "solution_articles", ["account_id", "folder_id", "title"], :name => "index_solution_articles_on_account_id_and_folder_id_and_title", :length => {"account_id"=>nil, "folder_id"=>nil, "title"=>10}
  add_index "solution_articles", ["account_id", "parent_id", "language_id"], :name => "index_articles_on_account_id_parent_id_and_language"
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
    t.integer  "parent_id",   :limit => 8
    t.integer  "language_id"
  end

  add_index "solution_categories", ["account_id", "name"], :name => "index_solution_categories_on_account_id_and_name", :unique => true
  add_index "solution_categories", ["account_id", "parent_id", "language_id"], :name => "index_solution_categories_on_account_id_parent_id_and_language"

  create_table "solution_category_meta", :force => true do |t|
    t.integer  "position"
    t.boolean  "is_default",              :default => false
    t.integer  "account_id", :limit => 8
    t.datetime "created_at",                                 :null => false
    t.datetime "updated_at",                                 :null => false
  end

  add_index "solution_category_meta", ["account_id"], :name => "index_solution_category_meta_on_account_id"

  create_table "solution_customer_folders", :force => true do |t|
    t.integer  "customer_id", :limit => 8
    t.integer  "folder_id",   :limit => 8
    t.integer  "account_id",  :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "folder_meta_id", :limit => 8
  end

  add_index "solution_customer_folders", ["account_id", "customer_id"], :name => "index_customer_folder_on_account_id_and_customer_id"
  add_index "solution_customer_folders", ["account_id", "folder_id"], :name => "index_customer_folder_on_account_id_and_folder_id"
  add_index "solution_customer_folders", ["account_id", "folder_meta_id"], :name => "index_solution_customer_folders_on_account_id_folder_meta_id"

  create_table "solution_folder_meta", :force => true do |t|
    t.integer  "visibility",                :limit => 8
    t.integer  "position"
    t.boolean  "is_default",                             :default => false
    t.integer  "solution_category_meta_id", :limit => 8
    t.integer  "account_id",                :limit => 8,                    :null => false
    t.datetime "created_at",                                                :null => false
    t.datetime "updated_at",                                                :null => false
  end

  add_index "solution_folder_meta", ["account_id", "solution_category_meta_id", "position"], :name => "index_folder_meta_on_account_id_category_meta_and_position"

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
    t.integer  "parent_id",   :limit => 8
    t.integer  "language_id"
  end

  add_index "solution_folders", ["account_id", "category_id", "position"], :name => "index_solution_folders_on_acc_cat_pos"
  add_index "solution_folders", ["account_id", "parent_id", "language_id"], :name => "index_solution_folders_on_account_id_parent_id_and_language"
  add_index "solution_folders", ["category_id", "name"], :name => "index_solution_folders_on_category_id_and_name", :unique => true
  add_index "solution_folders", ["category_id", "position"], :name => "index_solution_folders_on_category_id_and_position"

  create_table "subscription_addon_mappings", :force => true do |t|
    t.integer "subscription_addon_id", :limit => 8
    t.integer "account_id",            :limit => 8
    t.integer "subscription_id",       :limit => 8
  end

  create_table "subscription_addons", :force => true do |t|
    t.string   "name"
    t.decimal  "amount",         :precision => 10, :scale => 2, :default => 0.0
    t.integer  "renewal_period"
    t.integer  "addon_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end


  create_table "sub_section_fields", :force => true do |t|
    t.integer  "account_id",            :limit => 8
    t.integer  "ticket_field_value_id", :limit => 8
    t.integer  "ticket_field_id",       :limit => 8
    t.integer  "position",              :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "sub_section_fields", ["account_id", "ticket_field_value_id"], :name => "index_sub_section_fields_on_account_id_and_ticket_field_value_id"

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
    t.text     "title",                            :null => false
    t.integer  "notification_type", :default => 1, :null => false
    t.text     "url",                              :null => false
  end

  create_table "subscription_currencies", :force => true do |t|
    t.string   "name"
    t.string   "billing_site"
    t.string   "billing_api_key"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.decimal  "exchange_rate",   :precision => 10, :scale => 5
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
    t.integer  "subscription_plan_id",      :limit => 8
    t.integer  "renewal_period"
    t.integer  "total_agents"
    t.integer  "free_agents"
    t.integer  "subscription_affiliate_id", :limit => 8
    t.integer  "subscription_discount_id"
    t.boolean  "revenue_type"
    t.decimal  "cmrr",                                   :precision => 10, :scale => 2
    t.datetime "created_at"
    t.datetime "updated_at"
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

  create_table "subscription_plan_addons", :force => true do |t|
    t.integer "subscription_addon_id", :limit => 8
    t.integer "subscription_plan_id",  :limit => 8
  end

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
    t.text     "price"
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
    t.integer  "subscription_currency_id",  :limit => 8
  end

  add_index "subscriptions", ["account_id"], :name => "index_subscriptions_on_account_id"
  add_index "subscriptions", ["subscription_currency_id"], :name => "index_subscriptions_on_subscription_currency_id"

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

  add_index "support_scores", ["account_id", "group_id", "created_at"], :name => "index_support_scores_on_accid_and_gid_and_created_at"
  add_index "support_scores", ["account_id", "scorable_id", "scorable_type"], :name => "index_support_scores_on_accid_scorable_id_scorable_type"
  add_index "support_scores", ["account_id", "user_id", "created_at"], :name => "index_support_scores_on_accid_and_uid_and_created_at"
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
  add_index "survey_results", ["surveyable_id", "surveyable_type"], :name => "index_survey_results_on_surveyable_id_and_surveyable_type"

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

  create_table "form_ticket_field_values", :force => true do |t|
    t.integer  "account_id",      :limit => 8
    t.integer  "form_id",         :limit => 8
    t.integer  "ticket_field_id", :limit => 8
    t.string   "value"
    t.integer  "position",        :limit => 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "ticket_form_fields", :force => true do |t|
    t.integer  "account_id",        :limit => 8
    t.integer  "form_id",           :limit => 8
    t.integer  "ticket_field_id",   :limit => 8
    t.string   "ff_col_name"
    t.string   "field_alias"
    t.integer  "position",          :limit => 8
    t.boolean  "sub_section_field"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "ticket_form_fields", ["account_id", "form_id", "ticket_field_id"], :name => "index_form_tkt_fields_on_acc_id_and_form_id_and_field_id", :unique => true
  add_index "ticket_form_fields", ["account_id", "form_id"], :name => "index_ticket_form_fields_on_account_id_and_form_id"

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
    t.boolean  "published",                 :default => false
    t.integer  "merged_topic_id", :limit => 8
    t.integer  "int_tc01"
    t.integer  "int_tc02"
    t.integer  "int_tc03"
    t.integer  "int_tc04"
    t.integer  "int_tc05"
    t.integer  "long_tc01",       :limit => 8
    t.integer  "long_tc02",       :limit => 8
    t.datetime "datetime_tc01"
    t.datetime "datetime_tc02"
    t.boolean  "boolean_tc01",                 :default => false
    t.boolean  "boolean_tc02",                 :default => false
    t.string   "string_tc01"
    t.string   "string_tc02"
    t.text     "text_tc01"
    t.text     "text_tc02"
  end

  add_index "topics", ["account_id", "published", "replied_at"], :name => "index_topics_on_account_id_and_published_and_replied_at"
  add_index "topics", ["account_id", "merged_topic_id"], :name => "index_topics_on_account_id_and_merged_topic_id"
  add_index "topics", ["forum_id", "published"], :name => "index_topics_on_forum_id_and_published"
  add_index "topics", ["forum_id", "replied_at"], :name => "index_topics_on_forum_id_and_replied_at"
  add_index "topics", ["forum_id", "sticky", "replied_at"], :name => "index_topics_on_sticky_and_replied_at"
  add_index "topics", ["forum_id"], :name => "index_topics_on_forum_id"

  create_table "user_accesses", :id => false, :force => true do |t|
    t.integer "user_id",    :limit => 8, :null => false
    t.integer "access_id",  :limit => 8, :null => false
    t.integer "account_id", :limit => 8, :null => false
  end

  add_index "user_accesses", ["access_id"], :name => "index_user_accesses_on_access_id"
  add_index "user_accesses", ["account_id"], :name => "index_user_accesses_on_account_id"
  add_index "user_accesses", ["user_id"], :name => "index_user_accesses_on_user_id"
  

  create_table "user_emails", :id => false, :force => true do |t|
    t.integer  "id",               :limit => 8,                    :null => false
    t.integer  "user_id",          :limit => 8,                    :null => false
    t.string   "email"
    t.integer  "account_id",       :limit => 8,                    :null => false
    t.string   "perishable_token"
    t.boolean  "verified",                      :default => false
    t.boolean  "primary_role",                  :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "user_emails", ["account_id", "email"], :name => "index_user_emails_on_account_id_and_email", :unique => true
  add_index "user_emails", ["account_id", "perishable_token"], :name => "index_account_id_perishable_token"
  add_index "user_emails", ["account_id", "user_id", "primary_role"], :name => "index_account_id_user_id_primary_role"
  add_index "user_emails", ["email"], :name => "user_emails_email"
  add_index "user_emails", ["id"], :name => "user_emails_id"

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
    t.string   "string_uc02"
    t.string   "string_uc03"
    t.string   "string_uc04"
    t.string   "string_uc05"
    t.string   "string_uc06"
  end

  add_index "users", ["account_id", "email"], :name => "index_users_on_account_id_and_email", :unique => true
  add_index "users", ["account_id", "external_id"], :name => "index_users_on_account_id_and_external_id", :unique => true, :length => {"account_id"=>nil, "external_id"=>20}
  add_index "users", ["account_id", "fb_profile_id"], :name => "index_users_on_account_id_fb_profile_id"
  add_index "users", ["account_id", "import_id"], :name => "index_users_on_account_id_and_import_id", :unique => true
  add_index "users", ["account_id", "mobile"], :name => "index_users_on_account_id_mobile"
  add_index "users", ["account_id", "name"], :name => "index_users_on_account_id_and_name"
  add_index "users", ["account_id", "phone"], :name => "index_users_on_account_id_phone"
  add_index "users", ["account_id", "twitter_id"], :name => "index_users_on_account_id_twitter_id"
  add_index "users", ["customer_id", "account_id"], :name => "index_users_on_customer_id_and_account_id"
  add_index "users", ["email"], :name => "index_users_on_email"
  add_index "users", ["id"], :name => "users_id"
  add_index "users", ["perishable_token", "account_id"], :name => "index_users_on_perishable_token_and_account_id"
  add_index "users", ["persistence_token", "account_id"], :name => "index_users_on_persistence_token_and_account_id"
  add_index "users", ["single_access_token", "account_id"], :name => "index_users_on_account_id_and_single_access_token", :unique => true
  add_index "users", ["account_id", "helpdesk_agent"], :name => "index_users_on_account_id_and_helpdesk_agent"
  
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
    t.integer  "vote",          :limit => 1,  :default => 1
    t.datetime "created_at",                                 :null => false
    t.string   "voteable_type", :limit => 30
    t.integer  "voteable_id",   :limit => 8,  :default => 0, :null => false
    t.integer  "user_id",       :limit => 8,  :default => 0, :null => false
    t.integer  "account_id",    :limit => 8
  end

  add_index "votes", ["user_id"], :name => "fk_votes_user"

  create_table "wf_filters", :force => true do |t|
    t.string   "type"
    t.string   "name"
    t.text     "data"
    t.integer  "user_id",          :limit => 8
    t.string   "model_class_name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id",       :limit => 8
  end

  add_index "wf_filters", ["user_id"], :name => "index_wf_filters_on_user_id"

  create_table "whitelisted_ips", :force => true do |t|
    t.integer  "account_id",             :limit => 8
    t.boolean  "enabled"
    t.text     "ip_ranges"
    t.boolean  "applies_only_to_agents"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "widgets", :force => true do |t|
    t.string  "name"
    t.string  "description"
    t.text    "script"
    t.integer "application_id", :limit => 8
    t.text    "options"
  end
  
  create_table "whitelist_users", :force => true do |t|
    t.integer "user_id",    :limit => 8
    t.integer "account_id", :limit => 8
  end
end
