class SupportScorePartition < ActiveRecord::Migration
  def self.up
  	execute("drop table support_scores")
  	execute("CREATE  TABLE   `support_scores`   (  `id`   bigint(20)   unsigned  NOT   NULL AUTO_INCREMENT, 
  		 `account_id` bigint(20) DEFAULT NULL, `user_id` bigint(20) DEFAULT NULL, `group_id` bigint(20) DEFAULT NULL, 
  		 `scorable_id`   bigint(20)   DEFAULT   NULL,`scorable_type`   varchar(255)   COLLATE utf8_unicode_ci DEFAULT NULL, 
  		 `score` int(11) DEFAULT NULL, `score_trigger` int(11) DEFAULT NULL, `created_at` datetime  DEFAULT   NULL, 
  		 `updated_at`  datetime   DEFAULT  NULL, index `support_scores_id` (`id`) ) 
  		  ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci PARTITION BY  HASH(account_id) PARTITIONS 128")
  end

  def self.down
  end
end
