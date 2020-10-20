Before('@db_clean') do
  DatabaseCleaner.clean_with(:truncation,
                               pre_count: true, reset_ids: false)
end

Before('@ticket_dynamo_clean') do
  delete_ticket_dynamo_table
end

Before do
  create_test_account
  set_request_headers
  SpamCounter.stubs(:count).returns(0)
  Account.current.features.marketplace.destroy
  Sidekiq::Worker.clear_all
end

Before('@admin') do
  login_admin
  @account.make_current
end

Before('@adv_ticketing') do
  ticket_dynamo_table_create
  Helpdesk::Ticket.any_instance.stubs(:manual_publish_to_rmq).returns(true)
end

After('@adv_ticketing') do
  Helpdesk::Ticket.any_instance.unstub(:manual_publish_to_rmq)
end

Before('@sla_policy') do
  conditions = { "ticket_type" => ["Incident"] }
  resolution_time = [7200, 10800, 14400, 18000] #[urgent, high, medium, low]
  response_time = [3600, 7200, 10800, 14400] #[urgent, high, medium, low]
  create_sla_policy(true, conditions, {}, {}, { :resolution_time => resolution_time, :response_time => response_time })
end

Before('@sla_policy1') do
  conditions = { "ticket_type" => ["Problem"] }
  resolution_time = [10800, 14400, 18000, 21600] #[urgent, high, medium, low]
  response_time = [7200, 10800, 14400, 18000] #[urgent, high, medium, low]
  create_sla_policy(true, conditions, {}, {}, { :resolution_time => resolution_time, :response_time => response_time })
end

Before('@sla_policy2') do
  conditions = { 'source' => [Helpdesk::Source::FORUM] }
  resolution_time = [3600, 7200, 10800, 14400] #[urgent, high, medium, low]
  response_time = [2700, 3600, 7200, 10800] #[urgent, high, medium, low]
  create_sla_policy(true, conditions, {}, {}, { :resolution_time => resolution_time, :response_time => response_time })
end

Before('@sla_policy3') do
  company = create_company({ :name => "Company 1" })
  conditions = { "company_id" => [company.id] }
  resolution_time = [2700, 3600, 7200, 10800] #[urgent, high, medium, low]
  response_time = [1800, 2700, 3600, 7200] #[urgent, high, medium, low]
  create_sla_policy(true, conditions, {}, {}, { :resolution_time => resolution_time, :response_time => response_time })
end

Before('@sla_policy4') do
  group = @account.groups.where(:name => "QA").first
  business_calendar = create_business_calendar({ :name => "BH for #{group.name}" })
  group.update_attributes({:business_calendar_id => business_calendar.id})
  conditions = { "group_id" => [group.id] }
  resolution_time = [1800, 2700, 3600, 7200] #[urgent, high, medium, low]
  response_time = [900, 1800, 2700, 3600] #[urgent, high, medium, low]
  create_sla_policy(true, conditions, {}, {}, { :resolution_time => resolution_time, :response_time => response_time })
end

Before('@sla_policy5') do
  group = @account.groups.where(:name => "Sales").first
  business_calendar = create_business_calendar({
                                                :name => "BH for #{group.name}",
                                                :business_time_data => { :working_hours => {
                                                                            1 => {:beginning_of_workday => "3:00 pm", :end_of_workday => "11:00 pm"},
                                                                            2 => {:beginning_of_workday => "3:00 pm", :end_of_workday => "11:00 pm"},
                                                                            3 => {:beginning_of_workday => "3:00 pm", :end_of_workday => "11:00 pm"},
                                                                            4 => {:beginning_of_workday => "3:00 pm", :end_of_workday => "11:00 pm"},
                                                                            5 => {:beginning_of_workday => "3:00 pm", :end_of_workday => "11:00 pm"}
                                                                          },
                                                                          :weekdays => [1, 2, 3, 4, 5],
                                                                          :fullweek => false
                                                                        }
                                              })
  group.update_attributes({:business_calendar_id => business_calendar.id})
  conditions = { "group_id" => [group.id] }
  resolution_time = [1500, 2100, 2700, 3300] #[urgent, high, medium, low]
  response_time = [1200, 1800, 2400, 3000] #[urgent, high, medium, low]
  create_sla_policy(true, conditions, {}, {}, { :resolution_time => resolution_time, :response_time => response_time })
end

Before('@sla_policy6') do
  group = @account.groups.where(:name => "Product Management").first
  business_calendar = create_business_calendar({ :name => "BH for #{group.name}", :time_zone => "Rome" })
  group.update_attributes({:business_calendar_id => business_calendar.id})
  conditions = { "group_id" => [group.id] }
  resolution_time = [1800, 2400, 3000, 3600] #[urgent, high, medium, low]
  response_time = [1500, 2100, 2700, 3300] #[urgent, high, medium, low]
  create_sla_policy(true, conditions, {}, {}, { :resolution_time => resolution_time, :response_time => response_time })
end

Before('@sla_policy7') do
  conditions = { "ticket_type" => ["Feature Request"] }
  resolution_time = [14400, 28800, 36000, 43200] #[urgent, high, medium, low]
  response_time = [7200, 14400, 28800, 36000] #[urgent, high, medium, low]
  override_bhrs = [true, true, true, true] #[urgent, high, medium, low]
  create_sla_policy(true, conditions, {}, {}, { :resolution_time => resolution_time, :response_time => response_time, :override_bhrs => override_bhrs })
end

Before('@sla_policy8') do
  group = @account.groups.where(:name => "Sales").first
  business_calendar = create_business_calendar({
                                                   :name => "BH for #{group.name}",
                                                   :business_time_data => { :working_hours => {
                                                       1 => {:beginning_of_workday => "12:00 am", :end_of_workday => "11:59:59 pm"},
                                                       2 => {:beginning_of_workday => "12:00 am", :end_of_workday => "11:59:59 pm"},
                                                       3 => {:beginning_of_workday => "12:00 am", :end_of_workday => "11:59:59 pm"},
                                                       4 => {:beginning_of_workday => "12:00 am", :end_of_workday => "11:59:59 pm"},
                                                       5 => {:beginning_of_workday => "12:00 am", :end_of_workday => "11:59:59 pm"}
                                                   },
                                                                            :weekdays => [1, 2, 3, 4, 5],
                                                                            :fullweek => false
                                                   }
                                               })
  group.update_attributes({:business_calendar_id => business_calendar.id})
  conditions = { "group_id" => [group.id] }
  resolution_time = [1500, 2100, 90000, 262800] #[urgent, high, medium, low]
  response_time = [1200, 1800, 2400, 3000] #[urgent, high, medium, low]
  create_sla_policy(true, conditions, {}, {}, { :resolution_time => resolution_time, :response_time => response_time })
end

Before('@sla_policy9') do
  group = @account.groups.where(:name => "Sales").first
  business_calendar = create_business_calendar({
                                                   :name => "BH for #{group.name}",
                                                   :business_time_data => { :working_hours => {
                                                       1 => {:beginning_of_workday => "12:00 am", :end_of_workday => "11:59:59 pm"},
                                                       2 => {:beginning_of_workday => "12:00 am", :end_of_workday => "11:59:59 pm"},
                                                       3 => {:beginning_of_workday => "12:00 am", :end_of_workday => "11:59:59 pm"},
                                                       4 => {:beginning_of_workday => "12:00 am", :end_of_workday => "11:59:59 pm"},
                                                       5 => {:beginning_of_workday => "12:00 am", :end_of_workday => "11:30:00 pm"}
                                                   },
                                                                            :weekdays => [1, 2, 3, 4, 5],
                                                                            :fullweek => false
                                                   }
                                               })
  group.update_attributes({:business_calendar_id => business_calendar.id})
  conditions = { "group_id" => [group.id] }
  resolution_time = [1500, 2100, 90000, 262800] #[urgent, high, medium, low]
  response_time = [1200, 1800, 2400, 3000] #[urgent, high, medium, low]
  create_sla_policy(true, conditions, {}, {}, { :resolution_time => resolution_time, :response_time => response_time })
end

Before('@sla_policy10') do
  group = @account.groups.where(:name => "Sales").first
  business_calendar = create_business_calendar({
                                                   :name => "BH for #{group.name}",
                                                   :business_time_data => { :working_hours => {
                                                       1 => {:beginning_of_workday => "12:30 am", :end_of_workday => "11:59:59 pm"},
                                                       2 => {:beginning_of_workday => "12:00 am", :end_of_workday => "11:59:59 pm"},
                                                       3 => {:beginning_of_workday => "12:00 am", :end_of_workday => "11:59:59 pm"},
                                                       4 => {:beginning_of_workday => "12:00 am", :end_of_workday => "11:59:59 pm"},
                                                       5 => {:beginning_of_workday => "12:00 am", :end_of_workday => "11:30:00 pm"}
                                                   },
                                                                            :weekdays => [1, 2, 3, 4, 5],
                                                                            :fullweek => false
                                                   }
                                               })
  group.update_attributes({:business_calendar_id => business_calendar.id})
  conditions = { "group_id" => [group.id] }
  resolution_time = [1500, 2100, 90000, 262800] #[urgent, high, medium, low]
  response_time = [1200, 1800, 2400, 3000] #[urgent, high, medium, low]
  create_sla_policy(true, conditions, {}, {}, { :resolution_time => resolution_time, :response_time => response_time })
end

Before('@sla_policy11') do
  group = @account.groups.where(:name => "Sales").first
  business_calendar = create_business_calendar({
                                                   :name => "BH for #{group.name}",
                                                   :business_time_data => { :working_hours => {
                                                       1 => {:beginning_of_workday => "9:00 am", :end_of_workday => "9:00 pm"},
                                                       2 => {:beginning_of_workday => "9:00 am", :end_of_workday => "9:00 pm"},
                                                       3 => {:beginning_of_workday => "9:00 am", :end_of_workday => "9:00 pm"},
                                                       4 => {:beginning_of_workday => "9:00 am", :end_of_workday => "9:00 pm"},
                                                       5 => {:beginning_of_workday => "9:00 am", :end_of_workday => "9:00 pm"}
                                                   },
                                                                            :weekdays => [1, 2, 3, 4, 5],
                                                                            :fullweek => false
                                                   }
                                               })
  group.update_attributes({:business_calendar_id => business_calendar.id})
  conditions = { "group_id" => [group.id] }
  resolution_time = [1500, 2100, 86400, 172801] #[urgent, high, medium, low]
  response_time = [1200, 1800, 86400, 3300] #[urgent, high, medium, low]
  create_sla_policy(true, conditions, {}, {}, { :resolution_time => resolution_time, :response_time => response_time })
end

After do
  logout
end