module Concerns::TimeSheetConcern
  extend ActiveSupport::Concern

  private

    def calculate_time_spent(time_entry)
      from_time = time_entry.start_time
      to_time = Time.zone.now
      if from_time.respond_to?(:to_time)
        from_time = from_time.to_time
        to_time = to_time.to_time
        running_time = ((to_time - from_time).abs).round
      end
      (time_entry.time_spent.to_i + running_time.to_i)
    end
end
