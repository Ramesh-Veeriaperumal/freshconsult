class FolderVisibilityMapping < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :folder_visibility_mapping do |t|
      t.integer   'account_id', limit: 8, null: false
      t.integer   'folder_meta_id', limit: 8, null: false
      t.references :mappable, polymorphic: true
      t.timestamps
    end

    add_index :folder_visibility_mapping, [:account_id, :mappable_id], name: 'index_folder_visibility_mapping_on_acc_and_mappable_id'

    add_index :folder_visibility_mapping, [:folder_meta_id, :mappable_id], name: 'index_visibility_mapping_on_foldermeta_and_mappable_id'

    add_index :folder_visibility_mapping, [:folder_meta_id, :mappable_type], name: 'index_visibility_mapping_on_foldermeta_and_mappable_type'
  end

  def down
    drop_table :folder_visibility_mapping
  end
end
