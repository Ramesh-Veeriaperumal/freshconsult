class PopulatePicklistValuesForType < ActiveRecord::Migration
  
  def self.up
    type_opt = {1 => "Question", 2 => "Incident", 3 => "Problem", 4 => "Feature Request", 5 => "Lead" }
    data_array = []
    Helpdesk::TicketField.find(:all,:conditions => {:name => 'ticket_type'}).each do |tkt_field|
      type_opt.each do |k,v|
        data_hash = {:pickable_id => tkt_field.id, :pickable_type => 'Helpdesk::TicketField', 
                           :value => v, :position => k }
        data_array.push(data_hash)
      end
    end
    Helpdesk::PicklistValue.create(data_array)
  end

  def self.down
  end
end
