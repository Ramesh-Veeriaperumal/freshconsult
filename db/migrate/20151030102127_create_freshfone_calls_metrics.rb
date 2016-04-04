class CreateFreshfoneCallsMetrics < ActiveRecord::Migration
shard :none
  def up
  	create_table :freshfone_call_metrics do |t|
  	  t.column :account_id, "bigint(20) unsigned DEFAULT NULL"
      t.column :call_id, "bigint(20) unsigned DEFAULT NULL"
  	  t.column :ivr_time, "bigint(11) DEFAULT NULL"
  	  t.column :hold_duration, "bigint(11) DEFAULT 0"
  	  t.column :call_work_time, "bigint(11) DEFAULT 0" 
  	  t.column :queue_wait_time, "bigint(11) DEFAULT NULL" 
  	  t.column :total_ringing_time, "bigint(11) DEFAULT NULL" 
  	  t.column :talk_time, "bigint(11) DEFAULT NULL" 
  	  t.column :answering_speed, "bigint(11) DEFAULT NULL" 
      t.column :handle_time, "bigint(11) DEFAULT 0" 
  	  t.datetime :ringing_at
      t.datetime :hangup_at
  	  t.datetime :answered_at

  	  t.timestamps
  	end
    add_index :freshfone_call_metrics, [ :account_id, :call_id]
  end

  def down
  	drop_table :freshfone_call_metrics
  end
end
