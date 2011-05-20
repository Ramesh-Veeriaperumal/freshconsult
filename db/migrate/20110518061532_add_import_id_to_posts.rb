class AddImportIdToPosts < ActiveRecord::Migration
  def self.up
    add_column :posts, :import_id, :integer , :limit => 8
  end

  def self.down
    remove_column :posts, :import_id
  end
end
