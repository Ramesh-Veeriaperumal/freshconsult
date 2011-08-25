class CreateSurveyResults < ActiveRecord::Migration
  def self.up
    create_table :survey_results do |t|
      t.integer :account_id, :limit => 8
      t.integer :survey_id, :limit => 8
      t.integer :surveyable_id, :limit => 8
      t.string :surveyable_type
      t.integer :customer_id, :limit => 8
      t.integer :agent_id, :limit => 8
      t.integer :response_note_id, :limit => 8
      t.integer :rating

      t.timestamps
    end
  end

  def self.down
    drop_table :survey_results
  end
end
