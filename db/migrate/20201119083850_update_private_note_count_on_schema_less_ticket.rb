# frozen_string_literal: true

class UpdatePrivateNoteCountOnSchemaLessTicket < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def self.up
    create_table :ticket_private_note_count do |t|
      t.integer  :account_id, limit: 8
      t.integer  :ticket_id, limit: 8
      t.integer  :third_party_note_count, limit: 8
      t.integer  :existing_private_note_count, limit: 8
      t.integer  :updated_private_note_count, limit: 8
      t.boolean  :migrated, default: false
    end
  end

  def self.down
    drop_table :ticket_private_note_count
  end
end
