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
        noti_info = {
          :mid => params[:mid],
          :mbody => params[:body],
          :metadata => params[:metadata],
          :ticket_display_id => params[:id]
        }
        CollaborationWorker.perform_async(noti_info)
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
end
