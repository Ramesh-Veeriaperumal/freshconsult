class Helpdesk::AuthorizationsController < ApplicationController
 
  before_filter { |c| c.requires_permission :manage_tickets }

  include HelpdeskControllerMethods

  def index
    @items = Helpdesk::Authorization.paginate(
      :page => params[:page], 
      :order => Helpdesk::Ticket::SORT_SQL_BY_KEY[(params[:sort] || :created_asc).to_sym],
      :per_page => 20)
  end
  
  def autocomplete #Copied from HelpDeskControllerMethods -Shan
      deliver_autocomplete autocomplete_scoper
  end
  
  def agent_autocomplete
     deliver_autocomplete autocomplete_scoper.technicians
  end

  def deliver_autocomplete auto_scoper
    items = auto_scoper.find(
      :all, 
      :conditions => ["email is not null and name like ? or email like ?", "%#{params[:v]}%", "%#{params[:v]}%"], 
      :limit => 1000)

    r = {:results => items.map {|i| {:id => i.email , :value => i.name }}}
    r[:results].push({:id => current_account.kbase_email, :value => ""}) if params[:v] =~ /(kb[ase]?.*)/
    
    respond_to do |format|
      format.json { render :json => r.to_json }
    end
    
  end

  def requester_autocomplete
     items = autocomplete_scoper.find(
      :all, 
      :conditions => ["name like ? or email like ? or phone like ?", "%#{params[:v]}%", "%#{params[:v]}%","%#{params[:v]}%"], 
      :limit => 1000)

    r = {:results => items.map {|i| {:details => i.name_details, :user_id => i.id, :value => i.name}}}
    r[:results].push({:id => current_account.kbase_email, :value => ""}) if params[:v] =~ /(kb[ase]?.*)/
    
    respond_to do |format|
      format.json { render :json => r.to_json }
    end
  end
protected

  def item_url
    helpdesk_authorizations_url
  end

  def autocomplete_field
    'email'
  end

  def autocomplete_scoper
    current_account.users
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
