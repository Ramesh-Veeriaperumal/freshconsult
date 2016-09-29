class Helpdesk::ScheduledTask < ActiveRecord::Base

  CONSECUTIVE_FAILUERS_LIMIT = 7

  CRON_FREQUENCY_IN_HOURS = 1.hour

  MAX_DANGLE_HOUR = 2   # not converted to hours, since it is multiplied with 'CRON_FREQUENCY_IN_HOURS' in 'dangling_tasks' scope

  MAX_DANGLE_TIME_IN_HOURS = MAX_DANGLE_HOUR.hour

  MIN_DANGLE_TIME_IN_MINUTES = 5.minutes

  DEAD_TASK_LIMIT_TIME_IN_HOURS = MAX_DANGLE_TIME_IN_HOURS + (0.5).hour
  
  FREQUENCY_NAME_TO_TOKEN = { :hourly   => 0,
                              :daily    => 1,
                              :weekly   => 2,
                              :monthly  => 3
                            }
  FREQUENCY_TOKEN_TO_NAME = FREQUENCY_NAME_TO_TOKEN.invert

  FREQUENCY_UNIT = { :hourly   => 1.hour,
                     :daily    => 1.day,
                     :weekly   => 7.day,
                     :monthly  => 1
                   }
  
  STATUS_NAME_TO_TOKEN = { :available    => 0,
                           :enqueued     => 1,
                           :in_progress  => 2,
                           :disabled     => 3,
                           :expired      => 4
                          }
  STATUS_TOKEN_TO_NAME = STATUS_NAME_TO_TOKEN.invert

  SCHEDULABLE_ALIAS = { 'Helpdesk::ReportFilter' => :scheduled_report, 'Reports::BuildNoActivity' => :build_no_activity }

  SCHEDULABLE_WORKER = { :scheduled_report => 'Reports::ScheduledReports'.constantize, :build_no_activity => 'Reports::BuildNoActivity'.constantize }

  INACTIVE_STATUS = [ STATUS_NAME_TO_TOKEN[:disabled], STATUS_NAME_TO_TOKEN[:expired] ]

  ACCOUNT_INDEPENDENT_TASKS = [ :build_no_activity ]
  
end