class AddGoodToBadColumnToSurveys < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :surveys, :atomic_switch => true do |m|
      m.add_column :good_to_bad, 'tinyint(1) DEFAULT 0'
    end
  end
end