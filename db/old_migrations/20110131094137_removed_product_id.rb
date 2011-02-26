class RemovedProductId < ActiveRecord::Migration
  def self.up
    remove_column :forum_categories, :product_id
  end

  def self.down
  end
end
