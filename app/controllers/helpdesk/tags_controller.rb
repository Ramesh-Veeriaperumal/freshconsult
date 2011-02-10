class Helpdesk::TagsController < ApplicationController  
  helper 'helpdesk/tickets'

  before_filter { |c| c.requires_permission :manage_tickets }

  include HelpdeskControllerMethods

  def index
    @tags = Helpdesk::Tag.paginate(
      :page => params[:page], 
      :conditions => { :account_id => current_account }, 
      :order => Helpdesk::Tag::SORT_SQL_BY_KEY[(params[:sort] || :activity_desc).to_sym],
      :per_page => 30)
  end

  def show
    @tickets = (params[:show_all] ? @tag.tickets : @tag.tickets.visible).paginate(
      :page => params[:page], 
      :order => TicketsFilter::SORT_SQL_BY_KEY[(params[:sort] || :created_asc).to_sym],
      :per_page => 10)
  end

end
