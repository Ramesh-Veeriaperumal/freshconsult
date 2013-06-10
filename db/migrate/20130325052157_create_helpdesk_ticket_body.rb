class CreateHelpdeskTicketBody < ActiveRecord::Migration
  def self.up
  	execute("CREATE TABLE `helpdesk_ticket_bodies` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `ticket_id` bigint(20) DEFAULT NULL,
  `description` mediumtext COLLATE utf8_unicode_ci,
  `description_html` mediumtext COLLATE utf8_unicode_ci,
  `account_id` bigint(20) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  KEY `index_helpdesk_ticket_bodies_id` (`id`),
  KEY `index_helpdesk_ticket_bodies_on_account_id_and_ticket_id` (`account_id`,`ticket_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci
PARTITION BY HASH(account_id)
PARTITIONS 128;")
  end

  def self.down
  	drop_table :helpdesk_ticket_bodies
  end
end
