class CreateSolutionArticles < ActiveRecord::Migration
  def self.up
    create_table :solution_articles do |t|
      t.string :title
      t.text :description
      t.integer :user_id
      t.integer :folder_id
      t.integer :status
      t.integer :art_type
      t.boolean :is_public

      t.timestamps
    end
  end

  def self.down
    drop_table :solution_articles
  end
end
