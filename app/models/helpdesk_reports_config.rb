class HelpdeskReportsConfig < ActiveRecord::Base

  include JSON	

  self.primary_key = :id
  not_sharded
  self.table_name =  "helpdesk_reports_config"

  def get_config
  	JSON.parse(config_json).symbolize_keys
  end
end