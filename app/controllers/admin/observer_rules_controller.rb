class Admin::ObserverRulesController < Admin::SupervisorRulesController

  NESTED_EVENTS_SEPERATION = ['nested_rules', 'from_nested_rules', 'to_nested_rules']
  before_filter :require_survey_rule, :only => [:edit]
  include SurveyRuleHelperMethods
	protected

    def scoper
      current_account.observer_rules
    end
    
    def all_scoper
      current_account.all_observer_rules
    end
    
    def human_name
      "Observer rule"
    end

    def edit_data
      @event_input = ActiveSupport::JSON.encode @va_rule.filter_data[:events]
      filter_data = change_to_in_operator @va_rule.filter_data[:conditions]
      @filter_input = ActiveSupport::JSON.encode filter_data
      @action_input = ActiveSupport::JSON.encode @va_rule.action_data
    end

    def get_event_performer
      [[-2, t('admin.observer_rules.event_performer')]]
    end

    def load_config
      super

      @agents[0..0] = ['--', t('any_val.any') ], ['', t('none')]
      @note_types = [ ['--', t('ticket.any_note')], [:public, t('ticket.public_note')],
                       [:private, t('ticket.private_note')] ]
      @ticket_actions = [ [:update, t('ticket.updated')], [:delete, t('ticket.deleted')],
                           [:marked_spam, t('ticket.marked_spam')] ]
      @time_sheet_actions = [ [:added, t('ticket.new_time_entry')], [:updated, t('ticket.updated_time_entry')] ]

      event_hash = [
        { :name => -1, :value => t('click_to_select_event') },
        { :name => 'priority', :value => t('observer_events.priority'), :domtype => 'dropdown', 
          :choices => [ ['--', t('any_val.any_priority')] ]+TicketConstants.priority_list.sort, :type => 2 },
        { :name => 'ticket_type', :value => t('observer_events.type'), :domtype => 'dropdown', 
          :choices => [ ['--', t('any_val.any_ticket_type')] ]+current_account.ticket_type_values.collect { |c| [ c.value, c.value ] },
          :type => 2 },
        { :name => 'status', :value => t('observer_events.status'), :domtype => 'dropdown', 
          :choices => [ ['--', t('any_val.any_status')] ]+Helpdesk::TicketStatus.status_names(current_account), :type => 2 },
        { :name => 'group_id', :value => t('observer_events.group'), :domtype => 'dropdown',
          :choices => [ ['--', t('any_val.any_group')] ]+@groups, :type => 2 },
        { :name => 'responder_id', :value => t('observer_events.agent'), :domtype => 'dropdown',
          :choices => @agents, :type => 2 },
        { :name => 'note_type', :value => t('observer_events.note'), :domtype => 'dropdown',
          :choices => @note_types, :type => 1, :valuelabel => t('event.type') },
        { :name => 'reply_sent', :value => t('observer_events.reply'), :domtype => 'label', :type => 0 },
        { :name => 'due_by', :value => t('observer_events.due_date'), :domtype => 'label', :type => 0 },
        { :name => 'ticket_action', :value => t('observer_events.ticket'), :domtype => 'dropdown',
          :choices => @ticket_actions, :type => 1 },
        { :name => 'time_sheet_action', :value => t('observer_events.time_entry'), :domtype => 'dropdown',
          :choices => @time_sheet_actions, :type => 1 },
      ]

      if current_account.custom_survey_enabled
        event_hash.push(
            { :name => 'customer_feedback', :value => t('observer_events.customer_feedback'), :domtype => 'dropdown',
              :choices =>[ ['--', t('any_val.any_feedback')] ]+current_account.custom_surveys.active.first.choice_names, :type => 1,
              :valuelabel => t('event.rating'), :condition => survey_featured_account?
            }) unless current_account.custom_surveys.active.blank?
      else
        event_hash.push(
          { :name => 'customer_feedback', :value => t('observer_events.customer_feedback'), :domtype => 'dropdown',
          :choices =>[ ['--', t('any_val.any_feedback')] ]+Survey.survey_names(current_account), :type => 1,
          :valuelabel => t('event.rating'), :condition => survey_featured_account? })
      end
      event_hash = event_hash.select{ |event| event.fetch(:condition, true) }
      add_custom_events event_hash
      @event_defs = ActiveSupport::JSON.encode event_hash
    end

    def add_custom_events event_hash
      special_cases = [['--', t('any_val.any_value')], ['', t('none')]]
      cf = current_account.ticket_fields.event_fields
      unless cf.blank? 
        event_hash.push({ :name => -1,
                          :value => "-----------------------" 
                          })
        cf.each do |field|
          event_hash.push({
            :name => field.flexifield_def_entry.flexifield_name,
            :value => "#{field.label} #{(field.field_type == "custom_checkbox") ? t('event.is') : t('event.updated')}",
            :field_type => field.field_type,
            :domtype => (field.field_type == "nested_field") ? 
                          "nested_field" :
                            field.flexifield_def_entry.flexifield_coltype,
            :choices => (field.field_type == "nested_field") ? 
                          (field.nested_choices_with_special_case special_cases) : 
                            special_cases+field.picklist_values.collect{ |c| [c.value, c.value ] },
            :type => (field.field_type == "custom_checkbox") ? 1 : 2,
            :nested_fields => nested_fields_by_dbname(field)
          })
        end
      end
    end

    def set_filter_data
      params[:performer_data][:members].map!(&:to_i) unless params[:performer_data][:members].nil?
      filter_data = {
        :performer => params[:performer_data],
        :events => params[:event_data].blank? ? [] : (ActiveSupport::JSON.decode params[:event_data]),
        :conditions => params[:filter_data].blank? ? [] : (ActiveSupport::JSON.decode params[:filter_data]),
      }
      set_nested_fields_data filter_data[:events]
      set_nested_fields_data filter_data[:conditions]
      @va_rule.filter_data = 
                filter_data.blank? ? [] : filter_data
    end
    
    def nested_fields_by_dbname ticket_field
      nestedfields = { :subcategory => "", :items => "" }
      if ticket_field.field_type == "nested_field"
        ticket_field.nested_ticket_fields.each do |field|
          nestedfields[(field.level == 2) ? :subcategory : :items] = 
              { :name => field.flexifield_def_entry.flexifield_name, :label => field.label }      
        end
      end
      nestedfields
    end

    def set_nested_fields_data(data)      
      data.each do |f|       
        NESTED_EVENTS_SEPERATION.each do |field|
          f[field] = 
              (ActiveSupport::JSON.decode f[field]).map{ |a| 
                                            a.symbolize_keys! } unless f[field].nil?
        end
        f.symbolize_keys!
        unless f[:from_nested_rules].nil?
          f[:nested_rule] = []
          f[:from_nested_rules].each_with_index do |content, index|
            f[:nested_rule][index] = {
                                      :name => content[:name],
                                      :from => content[:value],
                                      :to => f[:to_nested_rules][index][:value]
                                    }
          end
        end  
      end
    end

    private
    
    def survey_data
      {
        :rules => JSON.parse(ActiveSupport::JSON.encode @va_rule.filter_data[:events]),
        :name => 'customer_feedback',
        :survey_modified_msg => I18n.t('admin.survey_modified'),
        :survey_disabled_msg => I18n.t('admin.observer_rules.survey_disabled_rule')
      }
    end
end
