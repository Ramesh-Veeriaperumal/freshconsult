module TimeSheetConcern
  extend ActiveSupport::Concern

  private

    # Following method will stop running timer for the user. At a time one user can have only one timer.
    def update_running_timer(user_id)
      @time_cleared = current_account.time_sheets.find_by_user_id_and_timer_running(user_id, true)
      if @time_cleared
        @time_cleared.update_attributes(timer_running: false, time_spent: calculate_time_spent(@time_cleared))
      end
    end

    def calculate_time_spent(time_entry)
      from_time = time_entry.start_time
      to_time = Time.zone.now
      from_time = from_time.to_time if from_time.respond_to?(:to_time)
      to_time = to_time.to_time if to_time.respond_to?(:to_time)
      running_time =  ((to_time - from_time).abs).round
      (time_entry.time_spent.to_i + running_time)
    end
end
