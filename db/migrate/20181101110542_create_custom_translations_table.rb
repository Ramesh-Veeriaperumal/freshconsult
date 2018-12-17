class CreateCustomTranslationsTable < ActiveRecord::Migration
  
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :custom_translations, :force => true do |t|
      t.column :translatable_id, "bigint unsigned", :null => false
      t.string :translatable_type, :null => false
      t.integer :language_id, :null => false
      t.binary :translations
      t.column :account_id, "bigint unsigned", :null => false 
      t.timestamps
    end

    add_index :custom_translations, ["account_id", "translatable_type", "language_id", "translatable_id"], :name => "ct_acc_id_translatable_type_lang_id_translatable_id"
  end 

  def down
    drop_table :custom_translations
  end
end
