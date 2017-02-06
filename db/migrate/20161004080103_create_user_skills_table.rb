class CreateUserSkillsTable < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    execute("CREATE TABLE `user_skills` (
        `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        `user_id` bigint(20) DEFAULT NULL,
        `skill_id` bigint(20) DEFAULT NULL,
        `created_at` datetime DEFAULT NULL,
        `updated_at` datetime DEFAULT NULL,
        `account_id` bigint(20) DEFAULT NULL,
        `rank` int(11) DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `account_id_and_user_id_and_skill_id` (`account_id`,`user_id`,`skill_id`),
        KEY `skill_id_and_user_id` (`skill_id`,`user_id`)
      ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;"
    )
  end
  
end