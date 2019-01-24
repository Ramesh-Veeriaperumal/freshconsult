class AddIndexToSurveyResults < ActiveRecord::Migration

  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :survey_results, :atomic_switch => true do |m|
      m.add_index([:account_id, :survey_id, :agent_id, :created_at], 'index_survey_results_on_account_id_survey_id_agent_id_created_at')
      m.add_index([:account_id, :survey_id, :group_id, :created_at], 'index_survey_results_on_account_id_survey_id_group_id_created_at')
    end
  end

  def down
    Lhm.change_table :survey_results, :atomic_switch => true do |m|
      m.remove_index([:account_id, :survey_id, :agent_id, :created_at], 'index_survey_results_on_account_id_survey_id_agent_id_created_at')
      m.remove_index([:account_id, :survey_id, :group_id, :created_at], 'index_survey_results_on_account_id_survey_id_group_id_created_at')
    end
  end

end
