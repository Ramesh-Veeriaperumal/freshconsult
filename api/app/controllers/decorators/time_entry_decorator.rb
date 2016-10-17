class TimeEntryDecorator < ApiDecorator
  delegate :id, :billable, :note, :timer_running, :time_spent, :executed_at, :start_time, :created_at, :updated_at, :user_id, to: :record
  
  class << self
    def format_time_spent(time_spent)
      if time_spent.is_a? Numeric
        # converts seconds to hh:mm format say 120 seconds to 00:02
        hours, minutes = time_spent.divmod(60).first.divmod(60)
        #  formatting 9 to be displayed as 09
        format('%02d:%02d', hours, minutes)
      end
    end
  end
  
  def initialize(record, options)
    super
    @ticket = options[:ticket]
  end
  
  def to_hash
    {
      billable: billable,
      note: note,
      id: id,
      timer_running: timer_running,
      agent_id: user_id,
      ticket_id: @ticket.try(:display_id) || record.workable.display_id,
      company_id: defined?(@ticket) ? @ticket.try(:company_id) : record.workable.company_id,
      time_spent: time_spent,
      executed_at: executed_at.try(:utc),
      start_time: start_time.try(:utc),
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc)
    }
  end
end
