# require 'config/boot'
# require 'config/environment'
require File.expand_path('../../config/boot', __FILE__)
require File.expand_path('../../config/environment', __FILE__)
include Reports::Constants

Clockwork.every(1.hour, "ArchiveData_By_TimeZone", :at => "**:05", :tz => 'UTC') { 
	utc_time = Time.zone.now.utc
	time_zones = TIMEZONES_BY_UTC_TIME[utc_time.hour.to_s]
	yesterday_date_in_tz = utc_time.in_time_zone(time_zones[0]).to_date.yesterday
	Resque.enqueue(Reports::Workers::ArchiveDataByTimeZone, {:date => utc_time.strftime('%Y_%m_%d'), :hour => utc_time.hour.to_s, 
			:yesterday_date => yesterday_date_in_tz.to_s}) }

Clockwork.every(1.hour, "Load_ArchiveData_To_Redshift", :at => "**:35", :tz => 'UTC') { 
	utc_time = Time.zone.now.utc
	Resque.enqueue(Reports::Workers::LoadDataToRedshift, {:date => utc_time.strftime('%Y_%m_%d'), :hour => utc_time.hour.to_s}) }

Clockwork.every(1.hour, "Load_RegenerateData_To_Redshift", :at => "**:45", :tz => 'UTC') { 
	utc_time = Time.zone.now.utc
	date, hour = utc_time.strftime('%Y_%m_%d'), utc_time.hour
	if hour == 0
		datetime = 1.hour.ago.utc # we will load the data from folder which got created one hour ago 
		date, hour = datetime.strftime('%Y_%m_%d'), datetime.hour
	else
		hour = hour - 1
	end
	Resque.enqueue(Reports::Workers::LoadRegeneratedDataToRedshift, {:date => date, :hour => hour.to_s}) }

Clockwork.every(1.day, "Run_Redshift_Table_Vacuum", :at => "05:30", :tz => 'UTC') { 
		Resque.enqueue(Reports::Workers::RunRedshiftTableVacuum,{}) }
