class Helpdesk::TagsController < ApplicationController  
  helper 'helpdesk/tickets'

  before_filter { |c| c.requires_permission :manage_tickets }
  before_filter :set_selected_tab

  include HelpdeskControllerMethods

  def index
    @tags = Helpdesk::Tag.paginate(
      :page => params[:page], 
      :include =>[:tag_uses, :tickets],
      :conditions => { :account_id => current_account , :helpdesk_tag_uses =>{:taggable_type =>'Helpdesk::Ticket'} }, 
      :order => Helpdesk::Tag::SORT_SQL_BY_KEY[(params[:sort] || :activity_desc).to_sym],
      :per_page => 30)
  end

  def show
    
    logger.debug "tag.tickets :: #{@tag.tickets.inspect}"
    @tickets = (params[:show_all] ? @tag.tickets : @tag.tickets.visible).paginate(
      :page => params[:page], 
      :order => TicketsFilter::SORT_SQL_BY_KEY[(params[:sort] || :created_asc).to_sym],
      :per_page => 10)
      logger.debug "Tickets for the tag are :: #{@tickets.inspect}"
  end
  
  protected
  
   def set_selected_tab
      @selected_tab = :tickets
   end
 

end
