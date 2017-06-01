class Helpdesk::CollabTicketsController < ApplicationController
  include Helpdesk::NotePropertiesMethods #build_notes_last_modified_user_hash
  helper Helpdesk::ArchiveNotesHelper # needed to load note_lock_icon(_note.html)
  helper Helpdesk::ArchiveTicketsHelper #needed to load _sticky
  include Helpdesk::AdjacentTickets

  around_filter :run_on_slave
  before_filter :check_feature
  before_filter :load_or_show_error, :only => [:show, :latest_note, :prevnext, :notify]
  before_filter :validate_collab_user, :only => [:show]

  def show
    @collab_context = true
    @to_emails = @ticket.to_emails
    @ticket_notes = @ticket.conversation.reverse
    @ticket_notes_total = @ticket.conversation_count
    build_notes_last_modified_user_hash(@ticket_notes)
    render "/helpdesk/archive_tickets/show"
  end

  def latest_note
    if @ticket.nil?
      render :text => t("flash.general.access_denied")
    elsif verify_permission? || (Account.current.group_collab_enabled? && valid_token?)
      render :partial => "/helpdesk/shared/ticket_overlay", :locals => {:ticket => @ticket}
    else
      redirect_to latest_note_helpdesk_ticket_path(@ticket)
    end
  end

  def prevnext
    @previous_ticket = find_in_list(:prev).to_s
    @next_ticket = find_in_list(:next).to_s
    render "/helpdesk/archive_tickets/prevnext"
  end

  def notify
    if @ticket.nil?
      head :forbidden
    elsif verify_permission? || (Account.current.group_collab_enabled? && valid_token?)
      if params[:metadata].present?
        @ticket.collab_msg = prepare_notification_data
        @ticket.delayed_manual_publish_to_rmq("update", RabbitMq::Constants::RMQ_COLLAB_MSG_KEY)
        head :ok
      else
        head :bad_request
      end
    else
      head :forbidden
    end
  end

  private
    def load_or_show_error
      @item = @ticket = current_account.tickets.find_by_display_id(params[:id])
      @item || raise(ActiveRecord::RecordNotFound)
    end

    def verify_permission?
      current_user && current_user.has_ticket_permission?(@ticket)
    end

    def check_feature
      unless current_account.collaboration_enabled?
        pjax_safe_redirect_to_tickets
      end
    end

    def run_on_slave(&block)
      Sharding.run_on_slave(&block)
    end

    def valid_token?
      Collaboration::Ticket.new(params[:id]).valid_token?(params[:token])
    end

    def validate_collab_user
      if verify_permission? || !Account.current.group_collab_enabled?
        redirect_to helpdesk_ticket_path(@ticket, :collab => params[:collab], :message => params[:message])
      elsif !valid_token?
        flash[:notice] = t("flash.general.access_denied")
        pjax_safe_redirect_to_tickets
      end
    end

    def pjax_safe_redirect_to_tickets
      redirect_params = {}
      redirect_params[:pjax_redirect] = true if request.headers['X-PJAX']
      redirect_to helpdesk_tickets_url(redirect_params)
    end

    def append_token_to_user_data(meta)
      if meta["reply"].present?
        meta["reply"]["token"] = current_account.group_collab_enabled? ? Collaboration::Ticket.new(params[:id]).access_token(meta["reply"]["r_id"]).to_s : ""
      end

      if meta["hk_group_notify"].present?
        for group in meta["hk_group_notify"] do
          for user in group["users"] do
            user["token"] = current_account.group_collab_enabled? ? Collaboration::Ticket.new(params[:id]).access_token(user["user_id"]).to_s : ""
          end
        end
      end

      if meta["hk_notify"].present?
        for user in meta["hk_notify"] do
          user["token"] = current_account.group_collab_enabled? ? Collaboration::Ticket.new(params[:id]).access_token(user["user_id"]).to_s : ""
        end
      end
      return meta
    end

    def prepare_notification_data
      begin
        meta = JSON.parse(params[:metadata])          
      rescue JSON::ParserError => e
        raise e, "Invalid JSON string: #{params[:metadata]}"
      end

      data_with_token = append_token_to_user_data(meta)

      from_email = @ticket.selected_reply_email.scan( /<([^>]*)>/).to_s
      if from_email.blank?
        from_email = current_account.default_friendly_email
      end

      {
        :notification_data => {
          :client_id => Collaboration::Ticket::HK_CLIENT_ID,
          :current_domain => current_account.full_domain,
          :message_id => params[:mid],
          :message_body => params[:body],
          :mentioned_by_id => current_user.id.to_s,
          :mentioned_by_name => current_user.name,
          :requester_name => @ticket.requester[:name],
          :requester_email => @ticket.requester[:email],
          :from_address => from_email,
          :metadata => data_with_token
        }
      }
    end
end
