class AddIndexAccountIdSurveyIdCreatedAtToSurveyHandles < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :survey_handles, atomic_switch: true do |m|
      m.add_index([:account_id, :survey_id, :created_at], 'index_survey_handles_on_account_id_and_survey_id_and_created_at')
    end
  end

  def down
    Lhm.change_table :survey_handles, atomic_switch: true do |m|
      m.remove_index([:account_id, :survey_id, :created_at], 'index_survey_handles_on_account_id_and_survey_id_and_created_at')
    end
  end
end
