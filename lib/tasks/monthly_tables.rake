# def generator(current_table,next_table)
#   origin = Lhm::Table.new(current_table)
#   destination = Lhm::Table.new(next_table)
#   migration = Lhm::Migration.new(origin, destination)
#   entangler = Migrator::Generator.new(migration)
#   entangler.before
# end

namespace :monthly_tables do
  desc "Creating a monthly table spam_tickets and spam_notes"
  # Crontab should have the following command
  # 10     15     12     *     *  bundle exec rake monthly_tables:spam_ticket_and_note
  task :spam_tickets_and_notes => :environment do |task|
    #TODO: Trigger an email before creation of table
    Sharding.run_on_all_shards do
      table_name = Helpdesk::Mysql::Util.next_month_table_extension("spam_tickets")
      puts table_name
      shard_name = ActiveRecord::Base.current_shard_selection.shard
      auto_increment_id = AutoIncrementId[shard_name]
      ActiveRecord::Base.connection.execute(
        "CREATE TABLE if not exists #{table_name} (
        `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        `subject` varchar(255) DEFAULT NULL,
        `description` longtext,
        `account_id` bigint(20) unsigned DEFAULT NULL,
        `requester_id` bigint(20) unsigned DEFAULT NULL,
        `associations_data` longtext,
        `deleted` tinyint(1) DEFAULT NULL,
        `created_at` datetime DEFAULT NULL,
        `updated_at` datetime DEFAULT NULL,
        `ticket_id` bigint(20) DEFAULT NULL,
         KEY `index_spam_tickets_on_account_id_and_requester_id` (`account_id`,`requester_id`),
         KEY `index_spam_tickets_on_account_id_and_created_at` (`account_id`,`created_at`),
         KEY `spam_tickets_id` (`id`)
         )ENGINE=InnoDB DEFAULT CHARSET=utf8 ENGINE=InnoDB AUTO_INCREMENT=#{auto_increment_id} DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
         /*!50100 PARTITION BY HASH (account_id)
         PARTITIONS 128 */")
      table_name = Helpdesk::Mysql::Util.next_month_table_extension("spam_notes")
      ActiveRecord::Base.connection.execute(
        "CREATE TABLE if not exists #{table_name} (
        `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        `body` longtext,
        `account_id` bigint(20) unsigned DEFAULT NULL,
        `user_id` bigint(20) unsigned DEFAULT NULL,
        `spam_ticket_id` bigint(20) unsigned DEFAULT NULL,
        `associations_data` longtext,
        `created_at` datetime DEFAULT NULL,
        `updated_at` datetime DEFAULT NULL,
        `clipped_content` tinyint(1) NOT NULL DEFAULT '0',
        KEY `index_spam_notes_on_account_id_and_spam_ticket_id` (`account_id`,`spam_ticket_id`),
        KEY `index_spam_notes_on_account_id_and_user_id` (`account_id`,`user_id`),
        KEY `spam_notes_id` (`id`)
        )ENGINE=InnoDB DEFAULT CHARSET=utf8 ENGINE=InnoDB AUTO_INCREMENT=#{auto_increment_id} DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
        /*!50100 PARTITION BY HASH (account_id)
        PARTITIONS 128 */")
    end
    #TODO: Trigger an email on successful creation of table
  end

  desc "drop previous month tables for spam_tickets and spam_notes"
  # Crontab should have the following command
  # 10     15     16     *     *  bundle exec rake monthly_tables:drop_spam_tickets_and_notes
  task :drop_spam_ticket_and_note => :environment do |task|
    #TODO: Trigger an email before the drop of table is started
    Sharding.run_on_all_shards do
      table_name = Helpdesk::Mysql::Util.previous_month_table_extension("spam_tickets")
      ActiveRecord::Base.connection.execute("drop table if exists #{table_name}")
      table_name = Helpdesk::Mysql::Util.previous_month_table_extension("spam_notes")
      ActiveRecord::Base.connection.execute("drop table if exists #{table_name}")
    end
    #TODO: Trigger an email after the drop of table is started
  end

  task :create_trigger_for_ticket_and_note => :environment do |task|
    Sharding.run_on_all_shards do
      # create, delete trigger for tickets and notes
      Migrator::Generator.trigger_generate(Helpdesk::Mysql::Util.table_name_extension_monthly("spam_tickets"),
                                      Helpdesk::Mysql::Util.next_month_table_extension("spam_tickets"))
      Migrator::Generator.trigger_generate(Helpdesk::Mysql::Util.table_name_extension_monthly("spam_notes"),
                                      Helpdesk::Mysql::Util.next_month_table_extension("spam_notes"))
    end
  end
end
