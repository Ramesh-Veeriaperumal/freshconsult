class CreateSurveyScores < ActiveRecord::Migration
  def self.up
    create_table :survey_scores do |t|
      t.integer :account_id, :limit => 8
      t.integer :surveyable_id, :limit => 8
      t.string :surveyable_type
      t.integer :customer_id, :limit => 8
      t.integer :agent_id, :limit => 8
      t.integer :response_note_id, :limit => 8
      t.integer :resolution_speed
      t.integer :customer_rating
      t.integer :score

      t.timestamps
    end
  end

  def self.down
    drop_table :survey_scores
  end
end
