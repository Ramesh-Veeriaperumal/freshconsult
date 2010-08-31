class MakeNotesPolymorphic < ActiveRecord::Migration
  def self.up

    add_column :helpdesk_notes, :notable_id, :integer
    add_column :helpdesk_notes, :notable_type, :string


    Helpdesk::Note.all.each do |v| 
      v.notable_id = v.ticket_id
      v.notable_type = "Helpdesk::Ticket"
      v.save!
    end

    remove_column :helpdesk_notes, :ticket_id
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
