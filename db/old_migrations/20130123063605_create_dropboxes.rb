class CreateDropboxes < ActiveRecord::Migration
  def self.up
    create_table :helpdesk_dropboxes do |t|
      
      t.column :url,  :text
      t.column :account_id, :bigint
      t.timestamps

      t.references :droppable, :polymorphic => true
    end
  end

  def self.down
    drop_table :helpdesk_dropboxes
  end
end
