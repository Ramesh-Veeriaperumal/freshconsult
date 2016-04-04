class AddIndexToSurveyRemarks < ActiveRecord::Migration

  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :survey_remarks, :atomic_switch => true do |t|
      t.add_index [:account_id, :survey_result_id]
      t.add_index [:account_id, :note_id]
    end
  end

  def down
    Lhm.change_table :survey_remarks, :atomic_switch => true do |t|
      t.remove_index [:account_id, :survey_result_id]
      t.remove_index [:account_id, :note_id]
    end
  end
  
end
