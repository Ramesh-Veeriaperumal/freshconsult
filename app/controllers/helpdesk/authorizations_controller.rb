class Helpdesk::AuthorizationsController < ApplicationController
 

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
    if current_account.features?(:multiple_user_emails)
      items = auto_scoper.find(
      :all, 
      :select => ["users.id as `id` , users.name as `name`, user_emails.email as `email_found`"],
      :joins => ["INNER JOIN user_emails ON user_emails.user_id = users.id AND user_emails.account_id = users.account_id"],
      :conditions => ["(users.name like ? or user_emails.email like ?) and users.deleted = 0", "%#{params[:v]}%", "%#{params[:v]}%"], 
      :limit => 1000)
      r = {:results => items.map {|i| {:id => i.email_found, :value => i.name, :user_id => i.id }}}
      r[:results].push({:id => current_account.kbase_email, :value => ""}) if params[:v] =~ /(kb[ase]?.*)/
    else
      items = auto_scoper.find(
      :all, 
      :conditions => ["email is not null and name like ? or email like ?", "%#{params[:v]}%", "%#{params[:v]}%"], 
      :limit => 1000)
      r = {:results => items.map {|i| {:id => i.email, :value => i.name, :user_id => i.id }}}
      r[:results].push({:id => current_account.kbase_email, :value => ""}) if params[:v] =~ /(kb[ase]?.*)/
    end
    
    respond_to do |format|
      format.json { render :json => r.to_json }
    end
  end

  def company_autocomplete
    respond_to do |format|
      format.json { 
        render :json => current_account.companies.custom_search(params[:name]).map{
                                              |customer| [customer.name, customer.id]}
      }
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
