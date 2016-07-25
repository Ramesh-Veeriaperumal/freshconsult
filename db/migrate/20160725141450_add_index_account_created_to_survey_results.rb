class AddIndexAccountCreatedToSurveyResults < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :survey_results, :atomic_switch => true do |m|
        m.add_index [:account_id, :created_at], 'index_survey_results_on_account_id_and_created_at'
    end
  end

  def self.down
    Lhm.change_table :survey_results, :atomic_switch => true do |m|
        m.remove_index [:account_id, :created_at], 'index_survey_results_on_account_id_and_created_at'
    end
  end
end
