class Mobihelp::TicketInfo < ActiveRecord::Base

  self.primary_key = :id
  self.table_name =  :mobihelp_ticket_infos

  attr_accessible :app_name, :app_version, :os , :os_version, :sdk_version, :device_make, :device_model, :device_id, :ticket_id

  belongs_to_account

  has_one :debug_data,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy

  belongs_to :ticket
  belongs_to :mobihelp_device

  APP_INFO_VARS = %w{app_name app_identifier app_version app_locale app_install_time app_update_time os os_version os_locale device_make device_model 
                      device_sw_build active_network_type mobile_network_type mobile_network_operator_name 
                      mobile_network_country_code battery_level battery_status memory_level screen_orientation
                      storage_space_internal storage_space_sd mobihelp_sdk_version}

end
