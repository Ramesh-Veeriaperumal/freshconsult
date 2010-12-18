class Flexifields < ActiveRecord::Migration
  def self.up
    
    Helpdesk::Ticket.create_ff_tables!
  end

  def self.down
    Helpdesk::Ticket.drop_ff_tables!
  end
end
