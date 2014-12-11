class AddTimeColumnsToTicketStates < ActiveRecord::Migration
  
  def self.up
  	Lhm.change_table :helpdesk_ticket_states, :atomic_switch => true do |m|
      m.add_column :first_resp_time_by_bhrs, :integer
      m.add_column :resolution_time_by_bhrs, :integer
      m.add_column :avg_response_time_by_bhrs, :float
    end
  end

  def self.down
    Lhm.change_table :helpdesk_ticket_states, :atomic_switch => true do |m|
      m.remove_column :first_resp_time_by_bhrs
      m.remove_column :resolution_time_by_bhrs
      m.remove_column :avg_response_time_by_bhrs
    end
  end

end


