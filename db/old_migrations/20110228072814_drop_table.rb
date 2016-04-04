class DropTable < ActiveRecord::Migration
  def self.up
    
    drop_table :helpdesk_article_guides
    drop_table :helpdesk_articles
    drop_table :helpdesk_guides
    
  end

  def self.down
    
   create_table "helpdesk_guides", :force => true do |t|
      t.string   "name"
      t.boolean  "hidden",               :default => false
      t.integer  "article_guides_count"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "position",             :default => 0
      t.text     "description"
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
    end
  end
end
