class AddSurveyIdToSurveyHandles < ActiveRecord::Migration
  def self.up
    add_column :survey_handles, :survey_id, :integer, :limit => 8
    add_column :survey_handles, :survey_result_id, :integer, :limit => 8
    
    add_column :survey_remarks, :survey_result_id, :integer, :limit => 8
    remove_column :survey_remarks, :survey_score_id
    
    remove_column :survey_handles, :account_id
  end

  def self.down
    add_column :survey_handles, :account_id, :integer, :limit => 8
    
    add_column :survey_remarks, :survey_score_id, :integer, :limit => 8
    remove_column :survey_remarks, :survey_result_id
    
    remove_column :survey_handles, :survey_result_id
    remove_column :survey_handles, :survey_id
  end
end
