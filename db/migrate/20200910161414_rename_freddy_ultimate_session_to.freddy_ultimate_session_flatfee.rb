# frozen_string_literal: true

class RenameFreddyUltimateSessionToFreddyUltimateSessionFlatfee < ActiveRecord::Migration
  shard :none

  def up
    addon = Subscription::Addon.where(name: 'Freddy Ultimate Session').last
    addon.name = 'Freddy Ultimate Session Flatfee'
    addon.save!
  end

  def down
    addon = Subscription::Addon.where(name: 'Freddy Ultimate Session Flatfee').last
    addon.name = 'Freddy Ultimate Session'
    addon.save!
  end
end
