class Helpdesk::ScheduledTask < ActiveRecord::Base

  CONSECUTIVE_FAILUERS_LIMIT = 3

  CRON_FREQUENCY_IN_HOURS = 1.hour
  
  FREQUENCY_NAME_TO_TOKEN = { :hourly   => 0,
                              :daily    => 1,
                              :weekly   => 2,
                              :monthly  => 3
                            }
  FREQUENCY_TOKEN_TO_NAME = FREQUENCY_NAME_TO_TOKEN.invert

  FREQUENCY_UNIT = { :hourly   => 1.hour,
                     :daily    => 1.day,
                     :weekly   => 7.day,
                     :monthly  => 1.month
                   }
  
  STATUS_NAME_TO_TOKEN = { :available    => 0,
                           :enqueued     => 1,
                           :in_progress  => 2,
                           :disabled     => 3,
                           :expired      => 4
                          }
  STATUS_TOKEN_TO_NAME = STATUS_NAME_TO_TOKEN.invert

  SCHEDULABLE_ALIAS = { 'Helpdesk::ReportFilter' => :scheduled_report }

  SCHEDULABLE_WORKER = { :scheduled_report => 'Reports::ScheduledReports'.constantize }  
  
end