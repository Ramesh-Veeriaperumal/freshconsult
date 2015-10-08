module Helpers::TimeEntriesHelper
  include TicketHelper
  include CompanyHelper
  # Patterns
  def time_entry_pattern(expected_output = {}, time_entry)
    {
      note: expected_output[:note] || time_entry.note,
      ticket_id: expected_output[:ticket_id] || time_entry.workable.display_id,
      id: Fixnum,
      agent_id: expected_output[:agent_id] || time_entry.user_id,
      billable: (expected_output[:billable] || time_entry.billable).to_s.to_bool,
      timer_running: (expected_output[:timer_running] || time_entry.timer_running).to_s.to_bool,
      time_spent: expected_output[:time_spent] || TimeEntryDecorator.format_time_spent(time_entry.time_spent),
      executed_at: expected_output[:executed_at] || time_entry.executed_at,
      start_time: expected_output[:start_time] || time_entry.start_time,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  # Helpers
  def create_time_entry(options = {})
    ticket_id = create_ticket.id if options[:ticket_id].blank?
    time_entry = FactoryGirl.build(:time_sheet, user_id: options[:agent_id] || @agent.id,
                                                workable_id: options[:ticket_id] || ticket_id,
                                                account_id: @account.id,
                                                timer_running: options.key?(:timer_running) ? options[:timer_running] : options[:time_spent].blank?,
                                                time_spent: options[:time_spent] || 0,
                                                executed_at: options[:executed_at] || Time.zone.now.to_s,
                                                billable: options.key?(:billable) ? options[:billable] : true,
                                                note: Faker::Lorem.sentence)
    time_entry.save
    time_entry.reload
  end

  def v2_time_entry_payload
    v2_time_entry_params.to_json
  end

  def v2_time_entry_params
    {
      start_time: 4.days.ago.iso8601, executed_at: 89.days.ago.iso8601, time_spent: '89:09',
      agent_id: @agent.id, billable: true, timer_running: true, note: Faker::Lorem.paragraph
    }
  end

  def v1_time_entry_payload
    {
      time_entry: {
        start_time: 4.days.ago.iso8601, executed_at: 23.days.ago.iso8601, hhmm: '89:09',
        user_id: @agent.id, billable: true, timer_running: true, note: Faker::Lorem.paragraph
      }
    }.to_json
  end

  def v2_time_entry_update_payload
    {
      executed_at: 1.days.ago.iso8601, billable: false, note: Faker::Lorem.paragraph
    }.to_json
  end

  def v1_time_entry_update_payload
    {
      time_entry: { executed_at: 2.days.ago.iso8601, billable: false, note: Faker::Lorem.paragraph }
    }.to_json
  end
end
