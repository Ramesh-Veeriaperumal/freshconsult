class CreateSolutionDrafts < ActiveRecord::Migration
  
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :solution_drafts do |t|
      t.integer   "account_id",       :limit => 8, :null => false
      t.integer   "article_id",       :limit => 8
      t.integer   "category_meta_id", :limit => 8
      t.integer   "user_id",          :limit => 8
      t.string    "title"
      t.text      "meta"
      t.integer   "status"
      t.timestamp "modified_at"
      t.timestamps
    end
  end

  def down
    drop_table :solution_drafts
  end

end
