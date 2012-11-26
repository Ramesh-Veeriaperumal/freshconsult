class CreatePortalTemplates < ActiveRecord::Migration
  def self.up
    create_table :portal_templates do |t|
      t.integer :account_id,    :limit => 8, :null => false
      t.integer :portal_id,     :limit => 8, :null => false
      t.text :preferences
      t.text :header
      t.text :footer
      t.text :custom_css,       :limit => 16777215
      t.text :layout,           :limit => 16777215
      t.boolean :active,        :default => true
      t.timestamps
    end
  end

  def self.down
    drop_table :portal_templates
  end
end
