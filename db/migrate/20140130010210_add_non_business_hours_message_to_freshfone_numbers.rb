class AddNonBusinessHoursMessageToFreshfoneNumbers < ActiveRecord::Migration
  shard :none
  def self.up
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.add_column :non_business_hours_message, :text
    end
    ActiveRecord::Base.connection.execute("UPDATE freshfone_numbers set non_business_hours_message = '--- !ruby/object:Freshfone::Number::Message \nattachment_id: \nmessage: You have reached us outside of our hours of operation\nmessage_type: 2\nrecording_url: \"\"\ntype: :non_business_hours_message\n'")
  end

  def self.down
    Lhm.change_table :freshfone_numbers, :atomic_switch => true do |m|
      m.remove_column :freshfone_numbers, :non_business_hours_message
    end
  end
end
