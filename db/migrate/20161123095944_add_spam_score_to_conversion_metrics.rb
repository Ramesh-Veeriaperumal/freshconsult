class AddSpamScoreToConversionMetrics < ActiveRecord::Migration
  shard :all
	
  def self.up
    Lhm.change_table :conversion_metrics, :atomic_switch => true do |m|
      m.add_column :spam_score,  'tinyint(2) DEFAULT 0'
    end
  end
  
  def self.down
    Lhm.change_table :conversion_metrics, :atomic_switch => true do |m|
      m.remove_column :spam_score
    end
  end
end
