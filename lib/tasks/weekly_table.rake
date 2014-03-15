# This task will be run every thursday
# Crontab should have the following command
# 10     15     *     *     4  bundle exec rake monthly_tables:ticket_and_note_body
namespace :weekly_tables do
  desc "Creating a monthly table ticket_body"
  task :ticket_and_note_body => :environment do |task|
    Sharding.run_on_all_shards do
      table_name = Helpdesk::Mysql::Util.next_week_table_extension("helpdesk_ticket_bodies")
      ActiveRecord::Base.connection.execute(
        "CREATE TABLE if not exists #{table_name} (
  			id bigint(20) NOT NULL AUTO_INCREMENT,
  			ticket_id bigint(20) DEFAULT NULL,
  			description longtext,
  			description_html longtext,
  			account_id bigint(20) DEFAULT NULL,
  			created_at datetime DEFAULT NULL,
  			updated_at datetime DEFAULT NULL,
  			raw_text longtext,
  			raw_html longtext,
  			meta_info longtext,
  			version int(11) DEFAULT NULL,
  			UNIQUE KEY index_ticket_bodies_on_account_id_and_ticket_id (account_id,ticket_id),
  			KEY index_helpdesk_ticket_bodies_id (id)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci 
			/*!50100 PARTITION BY HASH (account_id)
			PARTITIONS 128 */")

      table_name = Helpdesk::Mysql::Util.next_week_table_extension("helpdesk_note_bodies")
			ActiveRecord::Base.connection.execute(    
				"CREATE TABLE if not exists #{table_name} (
  				id bigint(20) NOT NULL AUTO_INCREMENT,
  				note_id bigint(20) DEFAULT NULL,
  				body longtext,
  				body_html longtext,
  				full_text longtext,
 					full_text_html longtext,
  				account_id bigint(20) DEFAULT NULL,
  				created_at datetime DEFAULT NULL,
  				updated_at datetime DEFAULT NULL,
  				raw_text longtext,
  				raw_html longtext,
  				meta_info longtext,
  				version int(11) DEFAULT NULL,
  				UNIQUE KEY index_note_bodies_on_account_id_and_note_id (account_id,note_id),
  				KEY index_helpdesk_note_bodies_id (id)
			) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
			/*!50100 PARTITION BY HASH (account_id)
			PARTITIONS 128 */")
    end
  end
end
