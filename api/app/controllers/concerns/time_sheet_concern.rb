module TimeSheetConcern
  extend ActiveSupport::Concern

  private 

    # Following method will stop running timer for the user. At a time one user can have only one timer.
    def update_running_timer user_id
      @time_cleared = current_account.time_sheets.find_by_user_id_and_timer_running(user_id, true)
      if @time_cleared
         @time_cleared.update_attributes({:timer_running => false, :time_spent => calculate_time_spent(@time_cleared) }) 
      end
    end

    def calculate_time_spent time_entry
      from_time = time_entry.start_time
      to_time = Time.zone.now
      from_time = from_time.to_time if from_time.respond_to?(:to_time)
      to_time = to_time.to_time if to_time.respond_to?(:to_time)
      running_time =  ((to_time - from_time).abs).round 
      return (time_entry.time_spent + running_time)
    end

    def convert_duration(duration)
      if duration =~ /^([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$/
        time_pieces = duration.split(":")
        hours = time_pieces[0].to_i
        minutes = (time_pieces[1].to_f/60.0)

        duration = hours + minutes
      end

      (duration.to_f * 60 * 60).to_i
    end

end
