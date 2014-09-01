class CreateSolutionFolders < ActiveRecord::Migration
  def self.up
    create_table :solution_folders do |t|
      t.string :name
      t.text :description
      t.integer :account_id

      t.timestamps
    end
  end

  def self.down
    drop_table :solution_folders
  end
end
