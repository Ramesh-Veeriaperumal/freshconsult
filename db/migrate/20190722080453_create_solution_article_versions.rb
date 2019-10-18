class CreateSolutionArticleVersions < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    create_table :solution_article_versions do |t|
      t.integer :id, limit: 8, null: false
      t.integer :status, null: false
      t.boolean :live, null: false
      t.integer :version_no, limit: 8, null: false
      t.integer :article_id, limit: 8, null: false
      t.integer :account_id, limit: 8, null: false
      t.integer :user_id, limit: 8, null: false
      t.integer :published_by, limit: 8
      t.integer :thumbs_up, default: 0
      t.integer :thumbs_down, default: 0
      t.integer :hits, default: 0
      t.text :meta

      t.timestamps
    end

    add_index :solution_article_versions, [:account_id, :article_id], name: 'index_version_on_account_id_article_id'
    add_index :solution_article_versions, [:account_id, :article_id, :version_no], name: 'index_version_on_account_id_article_id_version_no', unique: true
    add_index :solution_article_versions, [:account_id, :article_id, :created_at], name: 'index_version_on_account_id_article_id_created_at'
  end

  def down
    drop_table :solution_article_versions
  end
end
