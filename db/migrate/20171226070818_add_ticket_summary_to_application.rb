class AddTicketSummaryToApplication < ActiveRecord::Migration
  shard :all
  
  def migrate(direction)
    self.send(direction)
  end

  def up
    ticket_summary = Integrations::Application.new(
      :name => "ticket_summary",
      :display_name => "integrations.ticket_summary.label",
      :description => "integrations.ticket_summary.desc",
      :listing_order => 51,
      :options => {
        :direct_install => true,
        :user_specific_auth => true,
        :before_create => {
          :clazz => 'Integrations::TicketSummary',
          :method => 'enable_ticket_summary'
        },
        :after_commit_on_destroy => {
          :clazz => 'Integrations::TicketSummary',
          :method => 'disable_ticket_summary'
        }
      },
      :application_type => "ticket_summary",
      :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
    ticket_summary.save
  end

  def down
    Integrations::Application.where(:name => "ticket_summary").first.destroy
  end
end
