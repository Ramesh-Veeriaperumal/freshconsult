class Admin::ObserverRulesController < Admin::SupervisorRulesController

	protected
    
    NESTED_FIELDS = ['nested_rules', 'from_nested_rules', 'to_nested_rules']

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
      @va_rule.performed_by = @va_rule.filter_data[:performed_by]
      @event_input = ActiveSupport::JSON.encode @va_rule.filter_data[:events]
      @filter_input = ActiveSupport::JSON.encode @va_rule.filter_data[:conditions]
      @action_input = ActiveSupport::JSON.encode @va_rule.action_data
    end

    def load_config
      super

      @agents[0] = ['--', t('any_val.any') ]
      @note_types = [ ['--', t('ticket.any_note')], [:public, t('ticket.public_note')],
                       [:private, t('ticket.private_note')] ]
      @ticket_actions = [ [:updated, t('ticket.updated')], [:deleted, t('ticket.deleted')],
                           [:marked_as_spam, t('ticket.marked_spam')] ]
      @time_sheet_actions = [ [:added, t('ticket.new_time_entry')], [:updated, t('ticket.updated_time_entry')] ]

      event_hash   = [
        { :name => -1, :value => "--- #{t('click_to_select_event')} ---" },
        { :name => 'priority', :value => t('ticket.priority'), :domtype => 'dropdown', 
          :choices => [ ['--', t('any_val.any_priority')] ]+Helpdesk::Ticket::PRIORITY_NAMES_BY_KEY.sort, :type => 2, 
          :postlabel => t('event.updated') },
        { :name => 'ticket_type', :value => t('ticket.type'), :domtype => 'dropdown', 
          :choices => [ ['--', t('any_val.any_ticket_type')] ]+current_account.ticket_type_values.collect { |c| [ c.value, c.value ] },
          :type => 2, :postlabel => t('event.updated') },
        { :name => 'status', :value => t('ticket.status'), :domtype => 'dropdown', 
          :choices => [ ['--', t('any_val.any_status')] ]+Helpdesk::TicketStatus.status_names(current_account), :type => 2,
          :postlabel => t('event.updated') },
        { :name => 'group_id', :value => t('ticket.group'), :domtype => 'dropdown',
          :choices => [ ['--', t('any_val.any_group')] ]+@groups, :type => 2, :postlabel => t('event.updated') },
        { :name => 'responder_id', :value => t('ticket.assigned_agent'),
          :type => 0, :postlabel => t('event.updated')},
        { :name => 'note', :value => t('ticket.note'), :domtype => 'dropdown',
          :choices => @note_types, :type => 1, :postlabel => t('event.added') },
        { :name => 'reply', :value => t('ticket.reply'), :domtype => 'label', :type => 0,
          :postlabel => t('event.sent') },
        { :name => 'due_by', :value => t('ticket.due_date'), :domtype => 'label', :type => 0,
          :postlabel => t('event.updated')},
        { :name => 'ticket', :value => t('ticket.ticket'), :domtype => 'dropdown',
          :choices => @ticket_actions, :type => 1 },
        { :name => 'int_tc01', :value => t('ticket.feedback'), :domtype => 'dropdown',
          :choices =>[ ['--', t('any_val.any_feedback')] ]+Survey.survey_names(current_account), :type => 1,
          :postlabel => t('event.received') },
        { :name => 'time_sheet', :value => t('ticket.time_entry'), :domtype => 'dropdown',
          :choices => @time_sheet_actions, :type => 1 },
        ]

      add_custom_events event_hash
      @event_defs = ActiveSupport::JSON.encode event_hash
    end

    def set_filter_data
      filter_data = {
        :performed_by => params[:va_rule][:performed_by],
        :events => params[:event_data].blank? ? [] : (ActiveSupport::JSON.decode params[:event_data]),
        :conditions => params[:filter_data].blank? ? [] : (ActiveSupport::JSON.decode params[:filter_data]),
      }
      set_nested_fields_data filter_data[:events]
      set_nested_fields_data filter_data[:conditions]
      @va_rule.filter_data = 
                filter_data.blank? ? [] : filter_data
    end
    
    def add_custom_events event_hash
      any_value = [['--', t('any_val.any_value')]]
      event_hash.push({ :name => -1,
                        :value => "------------------------------" 
                        }) unless current_account.ticket_fields.event_fields.blank? 
      current_account.ticket_fields.event_fields.each do |field|
        event_hash.push({
          :name => field.flexifield_def_entry.flexifield_name,
          :value => field.label,
          :field_type => field.field_type,
          :domtype => (field.field_type == "nested_field") ? 
                        "nested_field" :
                          field.flexifield_def_entry.flexifield_coltype,
          :choices => (field.field_type == "nested_field") ? 
                        (field.nested_choices any_value) : 
                          any_value+field.picklist_values.collect { |c| [c.value, c.value ] },
          :type => (field.field_type == "custom_checkbox") ? 1 : 2,
          :nested_fields => nested_fields(field)
        })
      end
    end


    def nested_fields ticket_field
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
        NESTED_FIELDS.each do |field|
          f[field] = 
              (ActiveSupport::JSON.decode f[field]).map{ |a| 
                                            a.symbolize_keys! } unless f[field].nil?
        end
        f.symbolize_keys!
        unless f[:from_nested_rules].nil?
          f[:nested_rule] = [{},{}]
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

    def additional_filters
    	[]
    end

    def additional_actions
    	super
    end
end
