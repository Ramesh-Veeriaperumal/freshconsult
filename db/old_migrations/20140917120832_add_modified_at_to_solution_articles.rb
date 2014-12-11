class AddModifiedAtToSolutionArticles < ActiveRecord::Migration
  
  shard :all

  def self.up
    Lhm.change_table :solution_articles, :atomic_switch => true do |m|
      m.add_column :modified_at, "datetime DEFAULT NULL"
    end
    execute("UPDATE solution_articles SET modified_at=updated_at")
  end

  def self.down
    Lhm.change_table :solution_articles, :atomic_switch => true do |m|
      m.remove_column :modified_at
    end
  end

end
