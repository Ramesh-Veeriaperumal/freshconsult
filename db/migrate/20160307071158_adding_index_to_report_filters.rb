class AddingIndexToReportFilters < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :report_filters, :atomic_switch => true do |m|
      m.add_index [:account_id, :user_id, :report_type], "index_report_filters_on_account_user_and_report_type"
    end
  end

  def down
    Lhm.change_table :report_filters, :atomic_switch => true do |m|
      m.remove_index [:account_id, :user_id, :report_type], "index_report_filters_on_account_user_and_report_type"
    end
  end
end
