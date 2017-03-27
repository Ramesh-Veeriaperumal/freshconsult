module Helpdesk::Activities
  class Activity
    attr_accessor :performer, :performed_time, :activity, :summary, 
            :rule, :note, :event_type, :activity_arr, :invalid, :to_email_failures, :cc_email_failures

    def initialize(params)
      @performer      = params[:performer]
      @performed_time = params[:performed_time]
      @activity       = params[:activity]
      @activity_arr   = params[:activity_arr]
      @summary        = params[:summary]
      @invalid        = params[:invalid]
      @rule           = @activity[:rule]  if @activity[:rule].present?
      if @activity[:note].present? && @activity[:note].first[0].present?
        @note         = @activity[:note].first[0]
        @to_email_failures = @activity[:note].first[2] if @activity[:note].first[2].present?
        @cc_email_failures = @activity[:note].first[3] if @activity[:note].first[3].present?
      end
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
      rule? ? @rule[:type_name] : nil
    end

    def rule_name
      rule? ? @rule[:name] : nil
    end

    def rule_id
      rule? ? @rule[:id] : nil
    end

    def rule_type
      rule? ? @rule[:type] : nil
    end
    
    def rule_exists?
      rule? ? @rule[:exists] : nil
    end
    
    def note_hash
      note? ? @note[1] : nil
    end
  end
end