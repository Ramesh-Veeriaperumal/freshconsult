class CreateParentChildTemplates < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    execute(
      "CREATE TABLE `parent_child_templates` (
      `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
      `account_id` bigint(20) DEFAULT NULL,
      `parent_template_id` bigint(20) unsigned NOT NULL,
      `child_template_id` bigint(20) unsigned NOT NULL,
      `created_at` datetime DEFAULT NULL,
      `updated_at` datetime DEFAULT NULL,
      PRIMARY KEY (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;"
    )

    add_index :parent_child_templates, [:parent_template_id],
              :name => 'index_parent_child_templates_on_parent_template_id'
    add_index :parent_child_templates, [:child_template_id],
              :name => 'index_parent_child_templates_on_child_template_id'
  end

  def down
    drop_table :parent_child_templates
  end
end