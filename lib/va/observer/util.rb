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

  def trigger_observer(model_changes, inline = false, system_event = false)
    @model_changes = model_changes.symbolize_keys unless model_changes.nil?
    @system_event = system_event
    if user_present?
      filter_observer_events(true, inline)
    else
      Va::Logger::Automation.log("user_present=false, @model_changes=#{@model_changes.present?}, current_user_present=#{User.current.present?}, survey_result?=#{survey_result?}, system_event?=#{system_event?}, zendesk_import?=#{zendesk_import?}, freshdesk_webhook?=#{freshdesk_webhook?}, sent_for_enrichment?=#{sent_for_enrichment?}", true)
    end
  end

  private

    def user_present?
      observer_condition = @model_changes && (User.current || survey_result? || system_event?) &&
            !zendesk_import? && !freshdesk_webhook? && !sent_for_enrichment?
      return observer_condition
    end

    def filter_observer_events(queue_events = true, inline = false)
      observer_changes = filter_observer_changes
      Va::Logger::Automation.log("Triggered object=#{self.class}, id=#{self.id}", true)
      Va::Logger::Automation.log("observer_changes_blank=#{observer_changes.blank?}, skip_observer=not_queue_events=#{!queue_events}") if observer_changes.blank? || !queue_events
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

    def filter_observer_changes
      observer_changes = {}
      filter_changes = proc do |event|
        event = event.to_sym
        observer_changes[event] = @model_changes[event] if @model_changes.key? event
      end
      events = service_task? ? SERVICE_TASK_EVENTS : TICKET_EVENTS
      events.each(&filter_changes)
      Account.current.event_flexifields_with_ticket_fields_from_cache.map(&:flexifield_name).each(&filter_changes)
      observer_changes
    end

    def send_events(observer_changes, inline = false)
      observer_changes.merge! ticket_event observer_changes
      doer = User.current
      doer_id = (self.class == Helpdesk::Ticket) ? doer.id : self.safe_send(FETCH_DOER_ID[self.class.name])
      note_id = self.id if self.class == Helpdesk::Note
      args = {
        doer_id: doer_id,
        ticket_id: fetch_ticket_id,
        current_events: observer_changes,
        enqueued_class: self.class.name,
        note_id: note_id,
        original_attributes: original_ticket_attributes
      }

      if self.class == Helpdesk::Ticket
        args[:model_changes] = @model_changes
        unless service_task?
          include_sbrr_state_attributes(args) if Account.current.skill_based_round_robin_enabled?
          args[:sla_args] = { sla_on_background: sla_on_background, sla_state_attributes: sla_state_attributes, sla_calculation_time: sla_calculation_time.to_i }
        end
      end
      if inline
        return User.run_without_current_user { Tickets::ObserverWorker.new.perform(args) } unless service_task?

        User.run_without_current_user { Tickets::ServiceTaskObserverWorker.new.perform(args) }
      elsif self.class == Helpdesk::Ticket and self.schedule_observer
        # skipping observer for send and set ticket operation & bulk ticket actions for skill
        Va::Logger::Automation.log "Skipping observer schedule_observer=true"
        self.observer_args = args
      else
        evaluate_on.try(:invoke_ticket_observer_worker, args)
      end
    end

    def send_system_events observer_changes
      args = { ticket_id: fetch_ticket_id, system_event: true, current_events: observer_changes,
               original_attributes: original_ticket_attributes }
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

    def include_sbrr_state_attributes(args)
      args[:sbrr_state_attributes] = sbrr_state_attributes
      args[:sbrr_state_attributes].each_key do |attribute|
        args[:sbrr_state_attributes][attribute] = @model_changes[attribute][0] if @model_changes[attribute].present?
      end
    end

    def original_ticket_attributes
      return {} unless Account.current.observer_race_condition_fix_enabled? && !service_task?

      Account.current.observer_condition_fields_from_cache.each_with_object({}) do |field, hash|
        hash[field] = case field
                      when 'last_interaction'
                        last_interaction_note_id
                      else
                        evaluate_on.safe_send(field)
                      end
      end
    end

    def last_interaction_note_id
      # When a note is added, observer will be enqueued via Ticket::UpdateStatesWorker.
      # There can be a delay in worker by which time, another note could be added. So, using self instead of querying last_interaction_note
      self.class == Helpdesk::Note ? id : evaluate_on.last_interaction_note.id
    end

    def service_task?
      self.class == Helpdesk::Ticket ? self.service_task? : false
    end
end
