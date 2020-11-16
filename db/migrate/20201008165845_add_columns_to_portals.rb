# frozen_string_literal: true

class AddColumnsToPortals < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def self.up
    Lhm.change_table :portals, atomic_switch: true do |m|
      m.add_column :enabled, 'boolean DEFAULT false'
      m.add_column :supported_languages, :text
      m.add_column :ticket_preferences, :text
      m.add_column :knowledge_base_preferences, :text
      m.add_column :forum_preferences, :text
      m.remove_column :solution_category_id
      m.remove_column :forum_category_id
    end
  end

  def self.down
    Lhm.change_table :portals, atomic_switch: true do |m|
      m.remove_column :enabled
      m.remove_column :supported_languages
      m.remove_column :ticket_preferences
      m.remove_column :knowledge_base_preferences
      m.remove_column :forum_preferences
      m.add_column :solution_category_id, 'bigint(20)'
      m.add_column :forum_category_id, 'bigint(20)'
    end
  end
end
