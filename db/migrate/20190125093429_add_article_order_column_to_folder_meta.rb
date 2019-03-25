class AddArticleOrderColumnToFolderMeta < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :solution_folder_meta, atomic_switch: true do |m|
      m.add_column :article_order, 'integer DEFAULT 1'
    end
  end

  def down
    Lhm.change_table :solution_folder_meta, atomic_switch: true do |m|
      m.remove_column :article_order
    end
  end
end
