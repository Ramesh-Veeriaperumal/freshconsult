class AddUniqueIndexToTranslationsTable < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :custom_translations, atomic_switch: true do |current_migration|
      current_migration.remove_index(['account_id', 'translatable_type', 'language_id', 'translatable_id'], 'ct_acc_id_translatable_type_lang_id_translatable_id')
      current_migration.add_unique_index(['account_id', 'translatable_type', 'language_id', 'translatable_id'], 'ct_acc_id_translatable_type_lang_id_translatable_id')
    end
  end

  def down
    Lhm.change_table :custom_translations, atomic_switch: true do |current_migration|
      current_migration.remove_index(['account_id', 'translatable_type', 'language_id', 'translatable_id'], 'ct_acc_id_translatable_type_lang_id_translatable_id')
      current_migration.add_index(['account_id', 'translatable_type', 'language_id', 'translatable_id'], 'ct_acc_id_translatable_type_lang_id_translatable_id')
    end
  end
end
