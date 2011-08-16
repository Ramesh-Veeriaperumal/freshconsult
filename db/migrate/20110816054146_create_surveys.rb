class CreateSurveys < ActiveRecord::Migration
  def self.up
    create_table :surveys do |t|
      t.integer :account_id, :limit => 8
      t.text :link_text
      t.integer :send_while

      t.timestamps
    end
  end

  def self.down
    drop_table :surveys
  end
end
