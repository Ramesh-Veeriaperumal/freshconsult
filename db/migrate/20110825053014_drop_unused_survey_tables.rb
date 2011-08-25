class DropUnusedSurveyTables < ActiveRecord::Migration
  def self.up
    drop_table :survey_scores
    drop_table :survey_points
  end

  def self.down
  end
end
