class AddLinkTicketsToApplication < ActiveRecord::Migration
  shard :all
  def up
    link_ticket = Integrations::Application.new(
      :name => "link_tickets",
      :display_name => "integrations.link_ticket.label",
      :description => "integrations.link_ticket.desc",
      :listing_order => 49,
      :options => {
        :direct_install => true,
        :user_specific_auth => true,
        :before_create => {
          :clazz => 'Integrations::AdvancedTicketing::LinkTicket',
          :method => 'enable_link_tkt'
        },
        :after_commit_on_destroy => {
          :clazz => 'Integrations::AdvancedTicketing::LinkTicket',
          :method => 'disable_link_tkt'
        }
      },
      :application_type => "link_tickets",
      :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
    link_ticket.save
  end

  def down
    Integrations::Application.where(:name => "link_tickets").first.destroy
  end
end
