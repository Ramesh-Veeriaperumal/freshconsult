class Helpdesk::TagsController < ApplicationController  
  helper 'helpdesk/tickets'

  before_filter :set_selected_tab

  include HelpdeskControllerMethods

  def index
    @tags = current_account.tags.paginate(
      :page => params[:page], 
      :include =>[:tag_uses],
      :conditions => { :helpdesk_tag_uses =>{:taggable_type =>'Helpdesk::Ticket'} }, 
      :order => Helpdesk::Tag::SORT_SQL_BY_KEY[(params[:sort] || :activity_desc).to_sym],
      :per_page => 30)
  end

  def show
    @tickets = (params[:show_all] ? @tag.tickets : @tag.tickets.visible).paginate(
      :page => params[:page], 
      :order => TicketsFilter::SORT_SQL_BY_KEY[(params[:sort] || :created_asc).to_sym],
      :per_page => 10)
  end
  
  protected
  
   def set_selected_tab
      @selected_tab = :tickets
   end
 

end
