class AddIndexesToSurveyHandles < ActiveRecord::Migration
 shard :all
  def up
    Lhm.change_table :survey_handles, :atomic_switch => true do |m|
	   m.add_index [:account_id, :surveyable_id, :surveyable_type], "index_on_account_id_and_surveyable_id_and_surveyable_type"
	end
  end
  
  def down
    Lhm.change_table :survey_handles, :atomic_switch => true do |m|
      m.remove_index "index_on_account_id_and_surveyable_id_and_surveyable_type"
    end
  end
end