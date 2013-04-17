class DropHelpdeskFormCustomizer < ActiveRecord::Migration
  def self.up
  	drop_table :helpdesk_form_customizers
  end

  def self.down
  end
end
