class CreateSkillsTable < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    execute("CREATE TABLE `skills` (
        `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        `name` varchar(255) DEFAULT NULL,
        `description` text,
        `match_type` varchar(255) DEFAULT NULL,
        `filter_data` text,
        `created_at` datetime DEFAULT NULL,
        `updated_at` datetime DEFAULT NULL,
        `account_id` bigint(20) DEFAULT NULL,
        `position` int(11) DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `account_id_and_position` (`account_id`,`position`)
      ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;
    ")
  end
  
end