require 'config/boot'
require 'config/environment'
include Reports::Constants

Clockwork.every(1.hour, "ArchiveData_By_TimeZone", :at => "**:05", :tz => 'UTC') { 
	utc_time = Time.zone.now.utc
	time_zones = TIMEZONES_BY_UTC_TIME[utc_time.hour.to_s]
	yesterday_date_in_tz = utc_time.in_time_zone(time_zones[0]).to_date.yesterday
	Resque.enqueue(Workers::ArchiveDataByTimeZone, {:date => utc_time.strftime('%Y_%m_%d'), :hour => utc_time.hour.to_s, 
			:yesterday_date => yesterday_date_in_tz.to_s}) }

Clockwork.every(1.hour, "Load_ArchiveData_To_Redshift", :at => "**:35", :tz => 'UTC') { 
	utc_time = Time.zone.now.utc
	Resque.enqueue(Workers::LoadDataToRedshift, {:date => utc_time.strftime('%Y_%m_%d'), :hour => utc_time.hour.to_s}) }
