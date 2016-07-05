class CreateTicketTemplate < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    execute(
      "CREATE TABLE `ticket_templates` (
      `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
      `account_id` bigint(20) DEFAULT NULL,
      `name` varchar(255) DEFAULT NULL,
      `description` text,
      `template_data` mediumtext COLLATE utf8_unicode_ci,
      `data_description_html` mediumtext COLLATE utf8_unicode_ci,
      `association_type` int(11) DEFAULT NULL,
      `folder_id` bigint(20) DEFAULT NULL,
      `created_at` datetime DEFAULT NULL,
      `updated_at` datetime DEFAULT NULL,
      PRIMARY KEY (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;"
    )

    add_index :ticket_templates, [:account_id, :name],
      :name => "index_ticket_templates_on_account_id_and_name", 
      :length => {:account_id=>nil, :name=>20}
    add_index :ticket_templates, [:account_id, :association_type], 
              :name => 'index_ticket_templates_on_account_id_and_association_type'
  end

  def down
    drop_table :ticket_templates
  end
end