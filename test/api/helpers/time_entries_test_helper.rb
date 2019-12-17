['ticket_helper.rb', 'company_helper.rb', 'group_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module TimeEntriesTestHelper
  include TicketHelper
  include CompanyHelper
  include GroupHelper
  # Patterns
  def time_entry_pattern(expected_output = {}, time_entry)
    {
      note: expected_output[:note] || time_entry.note,
      ticket_id: expected_output[:ticket_id] || time_entry.workable.display_id,
      company_id: expected_output[:company_id] || time_entry.workable.company_id,
      id: Fixnum,
      agent_id: expected_output[:agent_id] || time_entry.user_id,
      billable: (expected_output[:billable] || time_entry.billable).to_s.to_bool,
      timer_running: (expected_output[:timer_running] || time_entry.timer_running).to_s.to_bool,
      time_spent: expected_output[:time_spent] || format_time_spent(time_entry.time_spent),
      executed_at: expected_output[:executed_at] || time_entry.executed_at.utc.iso8601,
      start_time: expected_output[:start_time] || time_entry.start_time.utc.iso8601,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  # Helpers
  def create_time_entry(options = {})
    ticket_id = create_ticket.id if options[:ticket_id].blank?
    # match_json(result_pattern.ordered!) fails sporadically when more
    # than one timesheet contains the same executed_at value
    if options[:executed_at].blank?
      latest_time_sheet = Helpdesk::TimeSheet.first
      options[:executed_at] = latest_time_sheet.present? ? (latest_time_sheet.executed_at + 2.minutes).to_s : Time.zone.now.to_s
    end
    time_entry = FactoryGirl.build(:time_sheet, user_id: options[:agent_id] || @agent.id,
                                                workable_id: options[:ticket_id] || ticket_id,
                                                account_id: @account.id,
                                                timer_running: options.key?(:timer_running) ? options[:timer_running] : options[:time_spent].blank?,
                                                time_spent: options[:time_spent] || 0,
                                                executed_at: options[:executed_at],
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

  def format_time_spent(time_spent)
    if time_spent.is_a? Numeric
      # converts seconds to hh:mm format say 120 seconds to 00:02
      hours, minutes = time_spent.divmod(60).first.divmod(60)
      #  formatting 9 to be displayed as 09
      format('%02d:%02d', hours, minutes)
    end
  end
end
