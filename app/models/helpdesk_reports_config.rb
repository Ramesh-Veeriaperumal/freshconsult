class HelpdeskReportsConfig < ActiveRecord::Base

  include JSON	

  self.primary_key = :id
  self.table_name =  "helpdesk_reports_config"
  not_sharded

  def get_config
  	JSON.parse(config_json).symbolize_keys
  end
end