class CreateTableHelpWidget < ActiveRecord::Migration
    shard :all
    
    def migrate(direction)
        self.send(direction)
    end

    def up
        create_table :help_widgets do |t|
            t.column :account_id,   "bigint unsigned"
            t.column :product_id,   "bigint unsigned"
            t.string :name
            t.text :settings
            t.boolean :active, default: true
            t.timestamps
        end
        add_index :help_widgets, [ :account_id, :active ]
    end

    def down
        drop_table :help_widgets
    end
end
