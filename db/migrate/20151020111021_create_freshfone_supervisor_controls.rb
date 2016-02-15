class CreateFreshfoneSupervisorControls < ActiveRecord::Migration
shard :all
  
  def self.up
    execute(
      "CREATE TABLE `freshfone_supervisor_controls` (
      `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
      `account_id` bigint(20) NOT NULL,
      `call_id` bigint(20) NOT NULL,
      `supervisor_id` bigint(20) NOT NULL,
      `supervisor_control_type` int(11) DEFAULT '0',
      `sid` varchar(50) COLLATE utf8_unicode_ci DEFAULT NULL,
      `duration` int(11) DEFAULT NULL,
      `supervisor_control_status` int(11) DEFAULT 0,
      `cost` float DEFAULT NULL,
      `created_at` datetime DEFAULT NULL,
      `updated_at` datetime DEFAULT NULL,
      PRIMARY KEY (`id`),
      KEY `index_freshfone_supervisor_controls_on_call_id` (`call_id`),
      KEY `index_freshfone_supervisor_controls_on_account_id` (`account_id`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;"
    )
  end

  def self.down
    drop_table :freshfone_supervisor_controls
  end
end
