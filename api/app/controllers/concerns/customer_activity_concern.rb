module CustomerActivityConcern
  extend ActiveSupport::Concern

  def activities
    @activities_count = CompanyConstants::MAX_ACTIVITIES_COUNT
    activities = case params[:type]
                 when 'tickets'
                   ticket_activities
                 when 'archived_tickets'
                   @activities_count = CompanyConstants::MAX_ARCHIVE_TICKETS_ACTIVITIES_COUNT
                   @type = 'archive_tickets'
                   ticket_activities
                 when 'forums'
                   forum_activities
                 else
                   combined_activities
                 end
    activities = decorate_activities(activities)
    @activities = activities.each_with_object({}) do |a, ret|
      (ret[a.delete(:activity_type).to_sym.downcase] ||= []).push(a)
      ret
    end
    if @total_tickets && @total_tickets.length > @activities_count
      response.api_meta = { more_tickets: true }
    end
  end

  private

    def ticket_scope
      @item.is_a?(User) ? 'all_user_tickets' : 'all_company_tickets'
    end

    def ticket_preload_options
      if @type == 'tickets'
        [:tags, :ticket_states, :ticket_old_body, :requester]
      else
        [:responder]
      end
    end

    def ticket_activities
      @type ||= 'tickets'
      return if @type == 'archive_tickets' && !current_account.features_included?(:archive_tickets)
      @total_tickets ||= begin
        tickets = current_account.safe_send(@type)
                                 .preload(ticket_preload_options)
                                 .permissible(api_current_user)
                                 .safe_send(ticket_scope, @item.id)
                                 .newest(@activities_count + 1)
        @type == 'tickets' ? tickets.visible : tickets
      end
      @total_tickets.take(@activities_count)
    end

    def load_tickets(ids)
      current_account.tickets.where(display_id: ids)
                     .preload(ticket_preload_options)
                     .permissible(api_current_user)
                     .visible
    end

    def forum_activities
      return [] unless @item.is_a?(User)
      @forum_activities ||=
        (current_account.features?(:forums) ? @item.recent_posts.preload(topic: :forum) : [])
    end

    def load_posts(ids)
      current_account.posts.pick_published(ids).preload(topic: :forum)
    end

    def combined_activities
      ticket_activities + forum_activities
    end

    def construct_timeline_activities(items)
      items_data = items[:data]
      return [] if items_data.blank? 
      all_activities = []
      items_data.keys.each do |item_data|
        case item_data
        when :ticket_ids
          all_activities += load_tickets(items_data[:ticket_ids])
        when :post_ids
          all_activities += load_posts(items_data[:post_ids])
        end
      end
      all_activities
    end

    def decorate_activities(activities)
      activities.map do |act|
        case act.class.name
        when 'Helpdesk::Ticket', 'Helpdesk::ArchiveTicket'
          TicketDecorator.new(act, sideload_options: ['requester']).to_activity_hash
        when 'Post'
          Discussions::CommentDecorator.new(act, {}).to_activity_hash
        end
      end
    end
end
