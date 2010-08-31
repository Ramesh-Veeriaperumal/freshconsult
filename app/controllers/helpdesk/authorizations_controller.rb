class Helpdesk::AuthorizationsController < ApplicationController
  layout 'helpdesk/default'

  before_filter { |c| c.requires_permission :manage_users }

  include HelpdeskControllerMethods

  def index
    @items = Helpdesk::Authorization.paginate(
      :page => params[:page], 
      :order => Helpdesk::Ticket::SORT_SQL_BY_KEY[(params[:sort] || :created_asc).to_sym],
      :per_page => 20)
  end

protected

  def item_url
    helpdesk_authorizations_url
  end

  def autocomplete_field
    'name'
  end

  def autocomplete_scoper
    User
  end
  
  def autocomplete_id(item)
    item.id
  end

  def edit_error
    redirect_to :back
  end

  def create_error
    redirect_to :back
  end

end
