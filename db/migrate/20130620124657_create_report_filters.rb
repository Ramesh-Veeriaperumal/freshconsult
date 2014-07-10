class CreateReportFilters < ActiveRecord::Migration
	shard :none
  def self.up
  	create_table :report_filters do |t|
      t.integer     :report_type, :limit=>8
      t.string      :filter_name
      t.text        :data_hash
      t.column      :user_id, "bigint unsigned"
      t.column      :account_id, "bigint unsigned"
      
      t.timestamps
    end

    add_index :report_filters , [:account_id, :report_type], :name => 'index_report_filters_account_id_and_report_type'
  end

  def self.down
  	drop_table :report_filters
  end
end
