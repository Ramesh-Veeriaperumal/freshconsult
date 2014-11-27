class AddCreatedAtIndexToSurveyResults < ActiveRecord::Migration
  def self.up
  	Lhm.change_table :survey_results, :atomic_switch => true do |m|
  		m.add_index [:account_id, :created_at], "index_account_id_created_at"
  	end
  end

  def self.down
  	Lhm.change_table :survey_results, :atomic_switch => true do |m|
  		m.remove_index [:account_id, :created_at]
  	end
  end
end
