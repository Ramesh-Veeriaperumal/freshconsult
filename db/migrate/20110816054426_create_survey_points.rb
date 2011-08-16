class CreateSurveyPoints < ActiveRecord::Migration
  def self.up
    create_table :survey_points do |t|
      t.integer :survey_id, :limit => 8
      t.integer :resolution_speed
      t.integer :customer_mood
      t.integer :score

      t.timestamps
    end
  end

  def self.down
    drop_table :survey_points
  end
end
