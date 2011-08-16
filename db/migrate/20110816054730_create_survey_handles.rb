class CreateSurveyHandles < ActiveRecord::Migration
  def self.up
    create_table :survey_handles do |t|
      t.integer :account_id, :limit => 8
      t.integer :surveyable_id, :limit => 8
      t.string :surveyable_type
      t.string :id_token
      t.integer :sent_while
      t.integer :response_note_id, :limit => 8

      t.timestamps
    end
  end

  def self.down
    drop_table :survey_handles
  end
end
