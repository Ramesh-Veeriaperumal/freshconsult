class AddStatusToCustomTranslations < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def self.up
    Lhm.change_table :custom_translations, atomic_switch: true do |m|
      m.add_column :status, 'INT'
    end
  end

  def self.down
    Lhm.change_table :custom_translations, atomic_switch: true do |m|
      m.remove_column :status
    end
  end
end
