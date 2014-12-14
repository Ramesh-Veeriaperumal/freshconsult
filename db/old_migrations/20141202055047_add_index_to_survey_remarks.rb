class AddIndexToSurveyRemarks < ActiveRecord::Migration
 shard :all
  def self.up
    Lhm.change_table :survey_remarks, :atomic_switch => true do |m|
      m.add_index [:survey_result_id,:account_id], "index_survey_result_id_account_id"
    end
  end

  def self.down
    Lhm.change_table :survey_remarks, :atomic_switch => true do |m|
        m.remove_index [:survey_result_id,:account_id], "index_survey_result_id_account_id"
    end
  end
end
