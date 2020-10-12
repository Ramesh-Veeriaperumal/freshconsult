class AddAdditionalSettingsToBusinessCalendars < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :business_calendars, atomic_switch: true do |t|
      t.add_column :additional_settings, :text
    end
  end

  def down
    Lhm.change_table :business_calendars, atomic_switch: true do |t|
      t.remove_column :additional_settings
    end
  end
end
