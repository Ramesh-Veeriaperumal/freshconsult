module CustomerActivityConcern
  extend ActiveSupport::Concern

  def activities
    activities = case params[:type]
                 when 'tickets'
                   ticket_activities
                 when 'archived_tickets'
                   @type = 'archive_tickets'
                   ticket_activities
                 when 'forums'
                   forum_activities
                 else
                   combined_activities
                 end
    activities = decorate_activites(activities)
    @activities = activities.each_with_object({}) do |a, ret|
      (ret[a.delete(:activity_type).to_sym.downcase] ||= []).push(a)
      ret
    end
    if @total_tickets && @total_tickets.length > CompanyConstants::MAX_ACTIVITIES_COUNT
      response.api_meta = { more_tickets: true }
    end
  end

  private

    def ticket_scope
      @item.is_a?(User) ? 'all_user_tickets' : 'all_company_tickets'
    end

    def ticket_preload_options
      if @type == 'tickets'
        [:tags, :ticket_states, :ticket_old_body]
      else
        [:responder]
      end
    end

    def ticket_activities
      @type ||= 'tickets'
      return if @type == 'archive_tickets' &&
                !current_account.features_included?(:archive_tickets)
      @total_tickets ||= begin
        tickets = current_account.safe_send(@type)
                                 .preload(ticket_preload_options)
                                 .permissible(api_current_user)
                                 .safe_send(ticket_scope, @item.id)
                                 .newest(CompanyConstants::MAX_ACTIVITIES_COUNT + 1)
        @type == 'tickets' ? tickets.visible : tickets
      end
      @total_tickets.take(CompanyConstants::MAX_ACTIVITIES_COUNT)
    end

    def forum_activities
      return [] unless @item.is_a?(User)
      @forum_activities ||=
        (current_account.features?(:forums) ? @item.recent_posts.preload(topic: :forum) : [])
    end

    def combined_activities
      ticket_activities + forum_activities
    end

    def decorate_activites(activities)
      activities.map do |act|
        case act.class.name
        when 'Helpdesk::Ticket', 'Helpdesk::ArchiveTicket'
          TicketDecorator.new(act, {}).to_activity_hash
        when 'Post'
          Discussions::CommentDecorator.new(act, {}).to_activity_hash
        end
      end
    end
end
