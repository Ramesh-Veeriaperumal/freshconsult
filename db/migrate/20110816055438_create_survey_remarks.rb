class CreateSurveyRemarks < ActiveRecord::Migration
  def self.up
    create_table :survey_remarks do |t|
      t.integer :survey_score_id, :limit => 8
      t.integer :note_id, :limit => 8

      t.timestamps
    end
  end

  def self.down
    drop_table :survey_remarks
  end
end
