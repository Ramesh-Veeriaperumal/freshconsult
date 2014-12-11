class UpdateVoiceMailStatusToCalls < ActiveRecord::Migration
  shard :all
  def self.up
    execute "update freshfone_calls set call_status = 10 where call_type = 1 and call_status = 3 and recording_url IS NOT NULL and user_id is NULL and direct_dial_number is NULL"
  end

  def self.down
    execute "update freshfone_calls set call_status = 3 where call_status = 10"
  end
end
