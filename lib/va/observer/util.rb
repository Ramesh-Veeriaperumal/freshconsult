module Va::Observer::Util

  include Va::Observer::Constants
  include Va::Util
  include Redis::RedisKeys
  include Redis::OthersRedis  

  def self.included(base)
    base.class_eval do
      after_save :set_automation_thread_variables
    end
  end

  def trigger_observer model_changes, inline = false, system_event = false
    @model_changes = model_changes.symbolize_keys unless model_changes.nil?
    @system_event = system_event
    if user_present?
      filter_observer_events(true, inline)
    else
      Va::Logger::Automation.log "user_present=false"
      Va::Logger::Automation.log "@model_changes=#{@model_changes.inspect}, current_user_present=#{User.current.present?}, survey_result?=#{survey_result?}, system_event?=#{system_event?}, zendesk_import?=#{zendesk_import?}, freshdesk_webhook?=#{freshdesk_webhook?}, sent_for_enrichment?=#{sent_for_enrichment?}"
    end
  end

  private

    def user_present?
      observer_condition = @model_changes && (User.current || survey_result? || system_event?) &&
            !zendesk_import? && !freshdesk_webhook? && !sent_for_enrichment?
      return observer_condition
    end

    def filter_observer_events(queue_events=true, inline=false)
      observer_changes = @model_changes.inject({}) do |filtered, (change_key, change_value)| 
                              filter_event filtered, change_key, change_value  end
      Va::Logger::Automation.log "Triggered object=#{self.class}, id=#{self.id}"
      Va::Logger::Automation.log "Observer changes not present, model_changes=#{@model_changes.inspect}" if observer_changes.blank?
      Va::Logger::Automation.log "Skipping observer queue_events=true" if !queue_events
      return observer_changes unless queue_events
      if observer_changes.present?
        system_event? ? send_system_events(observer_changes) : send_events(observer_changes, inline)
      end
    end

    def merge_to_observer_changes(prev_changes,current_changes)
      changelist = current_changes.symbolize_keys

      #if observer rules changed the ticket group, Round Robin should be based on those changes
      prev_changes.delete(:responder_id) if changelist.has_key?(:group_id)
      changelist.merge!(prev_changes.symbolize_keys) { |key, v1, v2| v1 }

      changelist
    end

    def filter_event filtered, change_key, change_value
      ( TICKET_EVENTS.include?( change_key ) ||
        Account.current.event_flexifields_with_ticket_fields_from_cache.
                                          map(&:flexifield_name).map(&:to_sym).include?(change_key)
          ) ? filtered.merge!({change_key => change_value}) : filtered
    end

    def send_events observer_changes, inline = false
      observer_changes.merge! ticket_event observer_changes
      doer = User.current
      doer_id = (self.class == Helpdesk::Ticket) ? doer.id : self.safe_send(FETCH_DOER_ID[self.class.name])
      args = {
        :doer_id => doer_id,
        :ticket_id => fetch_ticket_id,
        :current_events => observer_changes,
        :enqueued_class => self.class.name
      }

      if self.class == Helpdesk::Ticket
        args[:model_changes] = @model_changes
        args[:sbrr_state_attributes] = sbrr_state_attributes if Account.current.skill_based_round_robin_enabled?
        args[:sla_args] = {:sla_on_background => sla_on_background, :sla_state_attributes => sla_state_attributes, :sla_calculation_time => sla_calculation_time.to_i}
      end
      if inline
        User.run_without_current_user { Tickets::ObserverWorker.new.perform(args) }
      elsif self.class == Helpdesk::Ticket and self.schedule_observer
        # skipping observer for send and set ticket operation & bulk ticket actions for skill
        Va::Logger::Automation.log "Skipping observer schedule_observer=true"
        self.observer_args = args
      else
        evaluate_on.try(:invoke_ticket_observer_worker, args)
      end
    end

    def send_system_events observer_changes
      args = { ticket_id: fetch_ticket_id, system_event: true, current_events: observer_changes }
      evaluate_on.try(:invoke_ticket_observer_worker, args)
    end

    def ticket_event current_events
      CHECK_FOR_EVENT_SPECIAL_CASES.each do |key|
        unless current_events[key].nil?
          bool = current_events[key][1]
          return UPDATE_EVENT_SPECIAL_CASES[bool][key] if bool
        end
      end 
      return TICKET_UPDATED
    end

    def survey_result?
      self.is_a?(SurveyResult) || self.is_a?(CustomSurvey::SurveyResult)
    end

    def system_event?
      defined?(@system_event) ? @system_event : false
    end

    def fetch_ticket_id
      @evaluate_on_id ||= self.send FETCH_EVALUATE_ON_ID[self.class.name]
    end

    def evaluate_on
      @evaluate_on ||= Account.current.tickets.find_by_id fetch_ticket_id
    end

    def set_automation_thread_variables
      Va::Logger::Automation.set_thread_variables(Account.current.id, fetch_ticket_id, User.current.try(:id))
    end

end
