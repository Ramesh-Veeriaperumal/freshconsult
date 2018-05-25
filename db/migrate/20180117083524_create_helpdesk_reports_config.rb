class CreateHelpdeskReportsConfig < ActiveRecord::Migration
  shard :none
  def up
  	create_table :helpdesk_reports_config, :force => true do |t|
      t.text        :name
      t.text        :config_json
      t.timestamps
    end
  end

  def down
  	 drop_table :helpdesk_reports_config
  end
end
