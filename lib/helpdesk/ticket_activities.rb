module Helpdesk::TicketActivities
	def self.included(base)
		base.send :include, InstanceMethods
	end

	module InstanceMethods

		include TicketConstants

		def create_activity(user, description, activity_data = {}, short_descr = nil)
      activities.create(
        :description => description,
        :short_descr => short_descr,
        :account => account,
        :user => user,
        :activity_data => activity_data
      ) if user
    end

    def destroy_activity(description, note_id)
      activity = activities.where({'description' => description}).detect{ |a| a.note_id == note_id }
      activity.destroy unless activity.blank?
    end
  
    def create_initial_activity
      return if self.disable_activities
      unless spam?
        if outbound_email?
          base_text =  'new_outbound' 
          who = responder
        else
          base_text =  'new_ticket' 
          who = requester
        end
        create_activity(who, "activities.tickets.#{base_text}.long", {}, "activities.tickets.#{base_text}.short") 
      end
    end

	  def update_activity
      return if self.disable_activities
      @model_changes.each_key do |attr|
        safe_send(ACTIVITY_HASH[attr.to_sym()]) if ACTIVITY_HASH.has_key?(attr.to_sym())
      end
    end

	  def create_source_activity
      create_activity(User.current, 'activities.tickets.source_change.long',
          {'source_name' => source_name}, 'activities.tickets.source_change.short')
    end
  
    def create_product_activity
      unless self.product
        create_activity(User.current, 'activities.tickets.product_change_none.long', {}, 
                                   'activities.tickets.product_change_none.short')
      else
        create_activity(User.current, 'activities.tickets.product_change.long',
          {'product_name' => self.product.name}, 'activities.tickets.product_change.short')
      end
    end
  
    def create_ticket_type_activity
       create_activity(User.current, 'activities.tickets.ticket_type_change.long',
          {'ticket_type' => ticket_type}, 'activities.tickets.ticket_type_change.short')
    end
  
    def create_group_activity
      unless group
          create_activity(User.current, 'activities.tickets.group_change_none.long', {}, 
                                   'activities.tickets.group_change_none.short')
      else
      create_activity(User.current, 'activities.tickets.group_change.long',
          {'group_name' => group.name}, 'activities.tickets.group_change.short')
      end
    end
  
    def create_status_activity
      create_activity(User.current, 'activities.tickets.status_change.long',
          {'status_name' => Helpdesk::TicketStatus.translate_status_name(ticket_status, "name")}, 'activities.tickets.status_change.short')
    end
  
    def create_priority_activity
       create_activity(User.current, 'activities.tickets.priority_change.long', 
          {'priority_name' => priority_name}, 'activities.tickets.priority_change.short')
 
    end

    def create_deleted_activity
      if deleted
        create_activity(User.current, 'activities.tickets.deleted.long',
         {'ticket_id' => display_id}, 'activities.tickets.deleted.short')
      else
        create_activity(User.current, 'activities.tickets.restored.long',
         {'ticket_id' => display_id}, 'activities.tickets.restored.short')
      end 
    end
  
    def create_assigned_activity
      unless responder
        create_activity(User.current, 'activities.tickets.assigned_to_nobody.long', {}, 
                                   'activities.tickets.assigned_to_nobody.short')
      else
        create_activity(User.current, 
          @model_changes[:responder_id][0].nil? ? 'activities.tickets.assigned.long' : 'activities.tickets.reassigned.long', 
            {'eval_args' => {'responder_path' => ['responder_path', 
              {'id' => responder.id, 'name' => responder.name}]}}, 
            'activities.tickets.assigned.short')
      end
    end

    def create_due_by_activity
      create_activity(User.current, 'activities.tickets.due_date_updated.long',
        {'eval_args' => {'due_date_updated' => ['formatted_dueby_for_activity', self.due_by.to_i]}}, 
          'activities.tickets.due_date_updated.short') if self.schema_less_ticket.manual_dueby && self.due_by
    end

    def create_scenario_activity(scenario_name)
      create_activity(User.current, 'activities.tickets.execute_scenario.long', 
        { 'scenario_name' => scenario_name }, 'activities.tickets.execute_scenario.short') if scenario_name.present?
    end

    def all_activities(page = 1, no_of_records = 50)
      first_page_count = 3
      if page.blank? or page.to_i == 1
        return activities.newest_first.paginate(:page => 1, :per_page => first_page_count)
      else
        return activities.newest_first.paginate(:page => page.to_i - 1, :per_page => no_of_records, :extra_offset => first_page_count)
      end
    end

    def activities_since(since_id)
      activities.newest_first.activity_since(since_id)
    end

    def activities_before(before_id)
      activities.newest_first.activity_before(since_id).reverse
    end

    def activities_count
      activities.size - 1 #Omitting the Ticket Creation activity
    end

	end
end
