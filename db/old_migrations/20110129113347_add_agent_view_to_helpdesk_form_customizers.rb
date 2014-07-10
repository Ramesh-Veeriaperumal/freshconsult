class AddAgentViewToHelpdeskFormCustomizers < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_form_customizers, :agent_view, :text
    add_column :helpdesk_form_customizers, :requester_view, :text
  end

  def self.down
    remove_column :helpdesk_form_customizers, :agent_view
    remove_column :helpdesk_form_customizers, :requester_view
  end
end
