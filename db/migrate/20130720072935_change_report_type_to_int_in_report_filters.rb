class ChangeReportTypeToIntInReportFilters < ActiveRecord::Migration
	shard :none
  def self.up
  	change_column :report_filters, :report_type, :integer
  end

  def self.down
  	change_column :report_filters, :report_type, :bigint
  end
end
