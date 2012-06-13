class PopulateHelpdeskTicketStatusesData < ActiveRecord::Migration
  def self.up
    Account.all.each do |account|
      account.ticket_status_values.create(
      [
        { :status_id => 2, :name => 'Open', :customer_display_name => 'Open', :is_default => true, :account => account },
        { :status_id => 3, :name => 'Pending', :customer_display_name => 'Pending', :is_default => true, :stop_sla_timer => true, :account => account },
        { :status_id => 4, :name => 'Resolved', :customer_display_name => 'Resolved', :is_default => true, :stop_sla_timer => true, :account => account },
        { :status_id => 5, :name => 'Closed', :customer_display_name => 'Closed', :is_default => true, :stop_sla_timer => true, :account => account }
      ])
    end
  end

  def self.down
  end
end
