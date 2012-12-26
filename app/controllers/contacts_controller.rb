class ContactsController < ApplicationController
    before_filter :requires_all_tickets_access 
    
   include HelpdeskControllerMethods
   before_filter :check_demo_site, :only => [:destroy,:update,:create]
   before_filter :set_selected_tab
   before_filter :check_agent_limit, :only =>  :make_agent
   before_filter :load_item, :only => [:show, :edit, :update, :make_agent]
   skip_before_filter :build_item , :only => [:new, :create]
   before_filter :set_mobile , :only => :show
  
   
   def check_demo_site
    if AppConfig['demo_site'][RAILS_ENV] == current_account.full_domain
      flash[:notice] = t(:'flash.not_allowed_in_demo_site')
      redirect_to :back
    end
  end
  
  def index
    begin
      @contacts = scoper.filter(params[:letter], params[:page], params.fetch(:state, "active"))
    rescue Exception => e
      @contacts = {:error => get_formatted_message(e)}
    end
    respond_to do |format|
      format.html do
        @tags = current_account.tags.with_taggable_type(User.to_s)
      end
      format.xml  do
        render :xml => @contacts.to_xml(:root => "users")
      end

      format.json  do
        render :json => @contacts.to_json
      end
      format.atom do
        @contacts = @contacts.newest(20)
      end
    end    
  end

  def new
    initialize_new_user
  end
  
  def quick_customer
    params[:user][:customer_id] = params[:customer_id]
    if build_and_save
        flash[:notice] = t(:'flash.contacts.create.success')
    else  
        check_email_exist
        flash[:notice] =  activerecord_error_list(@user.errors)        
    end
    customer = current_account.customers.find(params[:customer_id])
    redirect_to(customer_url(customer))
  end
  
  def create   
    if build_and_save    
      flash[:notice] = t(:'flash.contacts.create.success')
      respond_to do |format|
        format.html { redirect_to contacts_url }
        format.xml  { render :xml => @user, :status => :created, :location => contacts_url(@user) }
        format.widget { render :action => :show}
        format.js
      end
    else
      check_email_exist
      respond_to do |format|
        format.html { render :action => :new}
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity} # bad request
        format.widget { render :action => :show}
        format.js
      end
    end
  end

  def hover_card
    @user = current_account.all_users.find(params[:id])    
    render :partial => "hover_card"
  end
  
  def build_and_save
    @user = current_account.users.new #by Shan need to check later  
    company_name = params[:user][:customer]    
    unless company_name.blank?      
     params[:user][:customer_id] = current_account.customers.find_or_create_by_name(company_name).id 
    end    
    @user.signup!(params)
  end
  
  def show
    email = params[:email]
    @user = nil # reset the user object.
    @user = current_account.all_users.find_by_email(email) unless email.blank?
    @user = current_account.all_users.find(params[:id]) if @user.blank?
    @user_tickets_open_pending = current_account.tickets.requester_active(@user).visible.newest(5)
    respond_to do |format|
      format.html { }
      format.xml  { render :xml => @user.to_xml} # bad request
      format.json { render :json => @user.to_json}
      format.mobile { render :json => @user.to_mob_json }
    end
  end
  
  def delete_avatar
    load_item
    @user.avatar.destroy
    render :text => "success"
  end
  
  def update    
    company_name = params[:user][:customer]
    unless company_name.blank?     
      @item.customer_id = current_account.customers.find_or_create_by_name(company_name).id 
    else
      @item.customer_id = nil
    end
    @item.update_tag_names(params[:user][:tags]) # update tags in the user object
    if @item.update_attributes(params[cname])
      respond_to do |format|
        format.html { redirect_to contacts_url }
        format.xml  { head 200}
      end
    else
      check_email_exist
      respond_to do |format|
        format.html { render :action => 'edit' }
        format.xml  { render :xml => @item.errors, :status => :unprocessable_entity} #Bad request
      end
    end
  end
  
  def make_agent    
    @item.update_attributes(:delete =>false, :user_role =>User::USER_ROLES_KEYS_BY_TOKEN[:agent])      
    @agent = current_account.agents.new
    @agent.user = @item 
    @item.deleted = false
    @agent.occasional = false
    respond_to do |format|
      if @agent.save        
        format.html { flash[:notice] = t(:'flash.contacts.to_agent') 
          redirect_to @item }
        format.xml  { render :xml => @item, :status => 200 }
      else
        format.html { redirect_to :back }
        format.xml  { render :xml => @agent.errors, :status => 500 }
      end   
    end 
  end
  
  def autocomplete   
    items = current_account.customers.find(:all, 
                                            :conditions => ["name like ? ", "%#{params[:v]}%"], 
                                            :limit => 30)

    r = {:results => items.map {|i| {:id => i.id, :value => i.name} } }  
    respond_to do |format|
      format.json { render :json => r.to_json }
    end    
  end
 
  def contact_email
    email = params[:email]
    @user = current_account.all_users.find_by_email(email) unless email.blank?
    puts "@user #{@user}"
    if @user.blank?
      initialize_new_user
      render :new, :layout => "widgets/contacts"
    else
      render :show, :layout => "widgets/contacts"
    end
  end

  def requires_all_tickets_access              
        access_denied unless current_user.can_view_all_tickets?
  end
  
protected

  def initialize_new_user
    @user = current_account.users.new
    @user.user_role = User::USER_ROLES_KEYS_BY_TOKEN[:customer]
    @user.avatar = Helpdesk::Attachment.new
    @user.time_zone = current_account.time_zone
    @user.language = current_account.language
  end

  def cname
      @cname ='user'
  end

  def scoper
    if !params[:tag].blank?
      tag = current_account.tags.find(params[:tag])
      tag.contacts
    elsif !params[:query].blank?
      query = params[:query]
      current_account.contacts.with_conditions(convert_query_to_conditions(query))
    else
      current_account.all_contacts
    end
  end
   
  def set_selected_tab
      @selected_tab = :customers
  end
  
  def check_email_exist
    if("has already been taken".eql?(@user.errors["email"]))        
			@existing_user = current_account.all_users.find(:first, :conditions =>{:users =>{:email => @user.email}})
		end
 end

 def check_agent_limit
   if current_account.reached_agent_limit? 
    flash[:notice] = t('maximum_agents_msg')
    redirect_to :back 
   end
  end

  private
    def convert_query_to_conditions(query_str)
      matches = query_str.split(/((\S+)\s*(is|like)\s*("([^\\"]|\\"|\\\\)*"|(\S+))\s*(or|and)?\s*)/)
      if matches.size > 1
        conditions = []; c_i=0
        matches.size.times{|i| 
          pos = i%7
          conditions[0] = "#{conditions[0]}#{matches[i]} " if(pos == 2) # property
          if(pos == 3) # operator
            oper = matches[i] == "is" ? "=" : matches[i]
            conditions[0] = "#{conditions[0]}#{oper} "
          end
          if(pos == 4) # match value
            conditions[0] = "#{conditions[0]}? "
            matches[i] = matches[i][1..-1] if matches[i][0] == 34 # remove opening double quote
            matches[i] = matches[i][0..-2] if matches[i][-1] == 34 # remove closing double quote
            matches[i] = matches[i].gsub("\\\\", "\\") # remove escape chars
            matches[i] = matches[i].gsub("\\\"", "\"") # remove escape chars
            matches[i] = "%#{matches[i]}%" if matches[i-1] == "like"
            conditions[c_i+=1] = matches[i]
          end
          conditions[0] = "#{conditions[0]}#{matches[i]} " if(pos == 6) # condition and/or
        }
        conditions
      else
        raise "Not able to parse the query."
      end
    end

    def get_formatted_message(exception)
      exception.message # TODO: Proper error reporting.
    end
end
