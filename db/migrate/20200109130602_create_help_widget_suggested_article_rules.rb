class CreateHelpWidgetSuggestedArticleRules < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    create_table :help_widget_suggested_article_rules do |t|
      t.column :help_widget_id, 'bigint unsigned'
      t.column :account_id, 'bigint unsigned'
      t.text :conditions
      t.text :filter
      t.integer :rule_operator, limit: 1, default: 1
      t.integer :position, limit: 2
      t.timestamps
    end
    add_index :help_widget_suggested_article_rules, [:account_id, :help_widget_id], name: 'index_help_widget_suggested_article_rules_on_account_id_and_w_id'
  end

  def down
    drop_table :help_widget_suggested_article_rules
  end
end
