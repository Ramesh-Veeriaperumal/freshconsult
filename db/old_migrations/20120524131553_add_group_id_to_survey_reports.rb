class AddGroupIdToSurveyReports < ActiveRecord::Migration
  def self.up
    add_column :survey_results, :group_id, "bigint unsigned"
  end

  def self.down
    remove_column :survey_results, :group_id
  end
end
