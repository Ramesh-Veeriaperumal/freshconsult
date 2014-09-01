class DropHelpdeskFormCustomizer < ActiveRecord::Migration
  shard :none
  def self.up
  	drop_table :helpdesk_form_customizers
  end

  def self.down
  end
end
