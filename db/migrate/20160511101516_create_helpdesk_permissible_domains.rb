class CreateHelpdeskPermissibleDomains < ActiveRecord::Migration

  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :helpdesk_permissible_domains do |t|
      t.string   :domain
      t.column   :account_id, "bigint unsigned", :null => false
      t.timestamps
    end

    add_index(:helpdesk_permissible_domains, [:account_id, :domain], :length => {:account_id=>nil, :domain => 20})
  end

  def down
    drop_table :helpdesk_permissible_domains
  end

end
