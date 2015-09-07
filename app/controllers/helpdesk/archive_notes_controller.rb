class Helpdesk::ArchiveNotesController < ApplicationController

  before_filter :check_feature
  before_filter :load_parent_ticket
  before_filter :load_note, :only => :full_text

  def index
    if params[:since_id].present?
      @notes = @parent.conversation_since(params[:since_id])
    elsif params[:before_id].present?
      @notes = @parent.conversation_before(params[:before_id])
    else
      @notes = @parent.conversation(params[:page])
    end
    
    if request.xhr?
      unless params[:v].blank? or params[:v] != '2'
        @ticket_notes = @notes.reverse        
        @ticket_notes_total = @parent.conversation_count
        render :partial => "helpdesk/archive_tickets/show/conversations"
      else
        render(:partial => "helpdesk/archive_tickets/note", :collection => @notes)
      end
    else 
      options = {}
      options.merge!({:human=>true}) if(!params[:human].blank? && params[:human].to_s.eql?("true"))  #to avoid unneccesary queries to users
      respond_to do |format|
        format.xml do
         render :xml => @notes.to_xml(options) 
        end
        format.json do
          render :json => @notes.to_json(options)
        end
        format.nmobile do
          array = []
          @notes.each do |note|
            array << note.to_mob_json
          end
          render :json => array
        end
      end
    end    
  end

  def full_text
    render :text => @item.full_text_html.to_s.html_safe
  end

  private

  def check_feature
    unless current_account.features?(:archive_tickets)
      redirect_to helpdesk_tickets_url
    end
  end

  def load_parent_ticket
    @parent = current_account.archive_tickets.find_by_display_id(params[:archive_ticket_id])
  end

  def load_note
    @item = @parent.archive_notes.find_by_id(params[:id])
  end
end
