# frozen_string_literal: true
class AddPortalIdToForumModerators < ActiveRecord::Migration

  shard :all

  def migrate(direction)
    send(direction)
  end

  def self.up
    Lhm.change_table :forum_moderators, atomic_switch: true do |m|
      m.add_column :portal_id, 'bigint(20)'
    end
  end

  def self.down
    Lhm.change_table :forum_moderators, atomic_switch: true do |m|
      m.remove_column :portal_id
    end
  end
end
