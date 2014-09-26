class AddHitsColumnToSolutionArticle < ActiveRecord::Migration
  
  shard :all

  def self.up
  	Lhm.change_table :solution_articles, :atomic_switch => true do |m|
  		m.add_column :hits, "int(11) DEFAULT '0'"
  	end
  end

  def self.down
  	Lhm.change_table :solution_articles, :atomic_switch => true do |m|
      m.remove_column :hits
  	end
  end

end
