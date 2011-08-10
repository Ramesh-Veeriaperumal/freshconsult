class AddValuesToTicketType < ActiveRecord::Migration
  def self.up
    type_opt = {1 => "Question", 2 => "Incident", 3 => "Problem", 4 => "Feature Request", 5 => "Lead" }
    Account.all.each do |account|
      tkts = account.tickets
      tkts.each do |tkt|
        tkt.tkt_type = type_opt[tkt.ticket_type]
        tkt.save
      end
      
    end
  end

  def self.down
  end
end
