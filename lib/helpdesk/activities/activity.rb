module Helpdesk::Activities
  class Activity
    attr_accessor :performer, :performed_time, :activity, :summary, 
            :rule, :note, :event_type, :activity_arr, :invalid

    def initialize(params)
      @performer      = params[:performer]
      @performed_time = params[:performed_time]
      @activity       = params[:activity]
      @activity_arr   = params[:activity_arr]
      @summary        = params[:summary]
      @invalid        = params[:invalid]
      @rule           = @activity[:rule]    if @activity[:rule].present?
      @note           = @activity[:note].first[0] if @activity[:note].present? and @activity[:note].first.present?
      @event_type     = @activity[:event_type]
    end

    def note?
      @note.present?
    end

    def rule?
      @rule.present?
    end

    def performer?
      @performer.present?
    end

    def system?
      @event_type == 0
    end

    def rule_type_name
      rule? ? @rule[0] : nil
    end

    def rule_name
      rule? ? @rule[1] : nil
    end

    def rule_id
      rule? ? @rule[2] : nil
    end

    def rule_type
      rule? ? @rule[3] : nil
    end
    
    def rule_exists?
      rule? ? @rule[4] : nil
    end
    
    def note_hash
      note? ? @note[1] : nil
    end
  end
end