class CreateHelpdeskTicketStatuses < ActiveRecord::Migration
  def self.up
    create_table :helpdesk_ticket_statuses do |t|
      t.column :status_id, "bigint unsigned"
      t.string :name
      t.string :customer_display_name
      t.boolean :stop_sla_timer, :default => false
      t.boolean :deleted, :default => false
      t.boolean :is_default, :default => false
      t.column :account_id, "bigint unsigned"
      t.column :ticket_field_id, "bigint unsigned"
      
      t.timestamps
    end
    add_index :helpdesk_ticket_statuses, [:ticket_field_id, :status_id], :name => 'index_helpdesk_ticket_statuses_on_ticket_field_id_and_status_id', :unique => true
  end

  def self.down
    drop_table :helpdesk_ticket_statuses
  end
end
