module TimeSheetsHelper
  def create_time_sheet(options = {})
    ticket_id = create_ticket.id if options[:ticket_id].blank?
    time_sheet = FactoryGirl.build(:time_sheet, user_id: options[:user_id] || @agent.id,
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
end
include TimeSheetsHelper
