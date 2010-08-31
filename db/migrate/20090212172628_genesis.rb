class Genesis < ActiveRecord::Migration
  def self.up
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
    end
    
    create_table "helpdesk_notes", :force => true do |t|
      t.integer  "ticket_id"
      t.text     "body"
      t.integer  "user_id"
      t.integer  "source",     :default => 0
      t.boolean  "incoming",   :default => false
      t.boolean  "private",    :default => true
      t.datetime "created_at"
      t.datetime "updated_at"
      t.boolean  "deleted",    :default => false
    end
    
    add_index "helpdesk_notes", ["ticket_id"], :name => "index_helpdesk_notes_on_ticket_id"
    
    create_table "helpdesk_reminders", :force => true do |t|
      t.string   "body"
      t.boolean  "deleted",    :default => false
      t.integer  "user_id"
      t.integer  "ticket_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end
    
    add_index "helpdesk_reminders", ["user_id"], :name => "index_helpdesk_reminders_on_user_id"
    add_index "helpdesk_reminders", ["ticket_id"], :name => "index_helpdesk_reminders_on_ticket_id"
    
    create_table "helpdesk_subscriptions", :force => true do |t|
      t.integer  "user_id"
      t.integer  "ticket_id"
      t.datetime "created_at"
      t.datetime "updated_at"
    end
    
    add_index "helpdesk_subscriptions", ["user_id"], :name => "index_helpdesk_subscriptions_on_user_id"
    add_index "helpdesk_subscriptions", ["ticket_id"], :name => "index_helpdesk_subscriptions_on_ticket_id"
    
    create_table "helpdesk_tag_uses", :force => true do |t|
      t.integer "ticket_id", :null => false
      t.integer "tag_id",    :null => false
    end
    
    add_index "helpdesk_tag_uses", ["ticket_id"], :name => "index_helpdesk_tag_uses_on_ticket_id"
    add_index "helpdesk_tag_uses", ["tag_id"], :name => "index_helpdesk_tag_uses_on_tag_id"
    
    create_table "helpdesk_tags", :force => true do |t|
      t.string  "name"
      t.integer "tag_uses_count"
    end
    
    create_table "helpdesk_tickets", :force => true do |t|
      t.string   "id_token"
      t.string   "access_token"
      t.string   "name"
      t.string   "phone"
      t.string   "email"
      t.text     "description"
      t.integer  "requester_id"
      t.integer  "responder_id"
      t.integer  "status",       :default => 1
      t.boolean  "urgent",       :default => false
      t.integer  "source",       :default => 0
      t.boolean  "spam",         :default => false
      t.boolean  "deleted",      :default => false
      t.datetime "created_at"
      t.datetime "updated_at"
      t.text     "address"
      t.boolean  "trained",      :default => false
    end
    
    add_index "helpdesk_tickets", ["id_token"], :name => "index_helpdesk_tickets_on_id_token", :unique => true
    add_index "helpdesk_tickets", ["requester_id"], :name => "index_helpdesk_tickets_on_requester_id"
    add_index "helpdesk_tickets", ["responder_id"], :name => "index_helpdesk_tickets_on_responder_id"

    unless table_exists?('users')
      create_table "users" do |t|
        t.string   "login",                     :limit => 40
        t.string   "name",                      :limit => 100, :default => ""
        t.string   "email",                     :limit => 100
        t.string   "crypted_password",          :limit => 40
        t.string   "salt",                      :limit => 40
        t.datetime "created_at"
        t.datetime "updated_at"
        t.string   "remember_token",            :limit => 40
        t.datetime "remember_token_expires_at"
      end

      add_index "users", ["login"], :name => "index_users_on_login", :unique => true
    end
    
    Helpdesk::Classifier.create(:name => 'spam', :categories => 'spam ham', :data => nil)
    if User.count > 0
      puts "\nYou should add a helpdesk admin role to at least one user, either via the Users link in the header or via the console:\n   Helpdesk::Authorization.create(:user => User.first, :role_token => 'admin')\n\n"
    else
      password = Password.phonemic
      puts "\nAdding helpdesk admin role to new user: login admin, password #{password}\n\n"
      u = User.create(:name => 'Admin', :login => 'admin', :password => password, :password_confirmation => password, :email => 'test@example.com')
    Helpdesk::Authorization.create(:user => u, :role_token => "admin")
    end
  end

  def self.down
  end
end
