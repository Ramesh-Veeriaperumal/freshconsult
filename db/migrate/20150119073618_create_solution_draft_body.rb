class CreateSolutionDraftBody < ActiveRecord::Migration
  shard :all

  def self.up
  	create_table :solution_draft_bodies do |t|
		t.integer  "account_id",   :limit => 8, :null => false
		t.integer  "draft_id",   :limit => 8
		t.text     "description", :limit => 16.megabytes + 1
		t.text     "seo_data"	    
	    t.timestamps
	end
  end

  def self.down
  	drop_table :solution_draft_bodies
  end
end
