module Helpers::TimeSheetsHelper
  # Patterns
  def time_sheet_pattern(expected_output = {}, time_sheet)
    {
      note: expected_output[:note] || time_sheet.note,
      ticket_id: expected_output[:ticket_id] || time_sheet.workable.display_id,
      id: Fixnum,
      agent_id: expected_output[:agent_id] || time_sheet.user_id,
      billable: (expected_output[:billable] || time_sheet.billable).to_s.to_bool,
      timer_running: (expected_output[:timer_running] || time_sheet.timer_running).to_s.to_bool,
      time_spent: expected_output[:time_spent] || format_time_spent(time_sheet.time_spent),
      executed_at: expected_output[:executed_at] || time_sheet.executed_at,
      start_time: expected_output[:start_time] || time_sheet.start_time,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  # Helpers
  def create_time_sheet(options = {})
    ticket_id = create_ticket.id if options[:ticket_id].blank?
    time_sheet = FactoryGirl.build(:time_sheet, user_id: options[:agent_id] || @agent.id,
                                                workable_id: options[:ticket_id] || ticket_id,
                                                account_id: @account.id,
                                                timer_running: options.key?(:timer_running) ? options[:timer_running] : options[:time_spent].blank?,
                                                time_spent: options[:time_spent] || 0,
                                                executed_at: options[:executed_at] || Time.zone.now.to_s,
                                                billable: options.key?(:billable) ? options[:billable] : true,
                                                note: Faker::Lorem.sentence)
    time_sheet.save
    time_sheet.reload
  end

  def v2_time_sheet_payload
    {
      start_time: 4.days.ago.to_s, executed_at: 89.days.ago.to_s, time_spent: '89:09', 
      agent_id: @agent.id, billable: true, timer_running: true, note: Faker::Lorem.paragraph
    }.to_json
  end

  def v1_time_sheet_payload
    {
      time_entry: {
        start_time: 4.days.ago.to_s, executed_at: 23.days.ago.to_s, hhmm: '89:09',
        user_id: @agent.id, billable: true, timer_running: true, note: Faker::Lorem.paragraph
      }
    }.to_json
  end

  def v2_time_sheet_update_payload
    {
      executed_at: 1.days.ago.to_s, billable: false, note: Faker::Lorem.paragraph
    }.to_json
  end

  def v1_time_sheet_update_payload
    {
      time_entry: { executed_at: 2.days.ago.to_s, billable: false, note: Faker::Lorem.paragraph }
    }.to_json
  end

  def format_time_spent(time_spent)
    if time_spent.is_a? Numeric
      hours, minutes = time_spent.divmod(60).first.divmod(60)
      format('%02d:%02d', hours, minutes)
    end
  end
end
include Helpers::TimeSheetsHelper
