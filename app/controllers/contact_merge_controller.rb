class ContactMergeController < ApplicationController
  #include Users::Activator TODO-RAILS3
  include ApplicationHelper
  include HelpdeskControllerMethods

  before_filter :load_multiple_items, :only => :confirm
  before_filter :get_source_user, :only => [:confirm, :complete]
  skip_before_filter :build_item , :only => :new

  def new
    @contact_search = Array.new
    @source_user = scoper.find(params[:id])  
    if @source_user.agent?
      unprocessable_entity
    else
      render :partial => "/contacts/new_contact_merge"
    end
  end

  def search
    source_user = scoper.find(params[:id])
    items = current_account.contacts.matching_users_from(params[:v]).without(source_user).find(:all,
     :include => [:primary_email, :avatar]).reject(&:helpdesk_agent?)
    r = {
      :results => items.map do |i| 
        {
          :id => i.id, 
          :name => i.name, 
          :email => i.email, 
          :title => i.job_title, 
          :company => i.company_name, 
          :searchKey => "#{i.additional_email.to_s}"+i.name, 
          :avatar =>  i.avatar ? i.avatar.content.url("thumb") : is_user_social(i, "thumb")
        }
      end
    }
    respond_to do |format|
      format.json { render :json => r.to_json }
    end
  end
  
  def confirm
    @target_user = @items
    @target_user.delete_if{ |x| (x.id == @source_user.id or x.agent?)}
    render :partial => "/contacts/merge_script"
  end
  
  def complete
    @target_users = scoper.find(:all, :conditions => {:id => params[:target]})
    @target_users.each do |target|
      target.user_emails.update_all({:user_id => @source_user.id, :primary_role => false})
    end
    
    Resque.enqueue(Workers::MergeContacts, {:source => params[:parent_user], :targets => params[:target]})
    flash[:notice] = t('merge_contacts.success')
    redirect_to @source_user
  end

  protected

    def get_source_user
      @source_user = scoper.find(params[:parent_user])
    end

    def scoper
      current_account.users
    end

    def cname
      @cname = 'user'
    end
end