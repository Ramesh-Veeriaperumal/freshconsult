class   SurveyPartition  <   ActiveRecord::Migration  
  def   self.up  
    execute("drop   table survey_results") 
    execute("drop table survey_remarks") 
    execute("drop table survey_handles")

   execute("CREATE  TABLE   `survey_results`   (  `id`   bigint(20)   unsigned  NOT   NULL AUTO_INCREMENT, `account_id` bigint(20) DEFAULT NULL, `survey_id` bigint(20) DEFAULT NULL, `surveyable_id`   bigint(20)   DEFAULT   NULL, `surveyable_type`   varchar(255)   COLLATE utf8_unicode_ci DEFAULT NULL, `customer_id` bigint(20) DEFAULT NULL, `agent_id` bigint(20) DEFAULT NULL, `response_note_id`  bigint(20) DEFAULT NULL, `rating`  int(11) DEFAULT NULL, `created_at` datetime  DEFAULT   NULL, `updated_at`  datetime   DEFAULT  NULL, index `survey_results_id` (`id`) ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci PARTITION BY  HASH(account_id) PARTITIONS 128")

   execute("CREATE  TABLE   `survey_remarks`   (  `id`   bigint(20)   unsigned  NOT   NULL AUTO_INCREMENT, `account_id`  bigint(20) DEFAULT NULL, `note_id`  bigint(20) DEFAULT NULL, `created_at` datetime DEFAULT NULL, `updated_at` datetime DEFAULT NULL, `survey_result_id` bigint(20) DEFAULT  NULL, index  `survey_remarks_id` (`id`)  ) ENGINE=InnoDB  DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci PARTITION BY HASH(account_id) PARTITIONS 128")

   execute("CREATE  TABLE   `survey_handles`   (  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT, `account_id`  bigint(20) DEFAULT NULL, `surveyable_id`  bigint(20) DEFAULT NULL,  `surveyable_type` varchar(255)  COLLATE  utf8_unicode_ci  DEFAULT NULL,  `id_token` varchar(255)  COLLATE utf8_unicode_ci  DEFAULT  NULL, `sent_while`  int(11) DEFAULT  NULL, `response_note_id`   bigint(20)  DEFAULT   NULL,  `created_at`   datetime  DEFAULT   NULL, `updated_at`    datetime DEFAULT   NULL,   `survey_id`    bigint(20)   DEFAULT    NULL, `survey_result_id` bigint(20) DEFAULT NULL,  index `survey_handles_id` (`id`))     ENGINE=InnoDB    DEFAULT     CHARSET=utf8 COLLATE=utf8_unicode_ci PARTITION BY HASH(account_id)     PARTITIONS    128")

  end

  def self.down
  end
  
end