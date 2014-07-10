class CreateHelpdeskIssues < ActiveRecord::Migration
  def self.up
    create_table :helpdesk_issues do |t|
      t.string   "title"
      t.text     "description"
      t.integer  "user_id"
      t.integer  "owner_id"
      t.integer  "status",       :default => 1
      t.boolean  "deleted",      :default => false
      t.timestamps
    end
  end

  def self.down
    drop_table :helpdesk_issues
  end
end
