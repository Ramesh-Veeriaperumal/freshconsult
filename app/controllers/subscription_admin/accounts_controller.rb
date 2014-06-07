class SubscriptionAdmin::AccountsController < ApplicationController
 
  include AdminControllerMethods
  
  around_filter :select_account_shard, :only => [:show]
  before_filter :check_super_admin_role, :only => [:add_day_passes, :add_feature, :change_url]


  def show
  	@account = Account.find(params[:id])
    note_id = Helpdesk::Note.maximum(:id, :conditions => [ "account_id = ?", @account.id ])
    @note = Helpdesk::Note.find_by_id(note_id)
  end
  
  def add_day_passes
   Sharding.select_shard_of(params[:id]) do 
    @account = Account.find(params[:id])
    if request.post? and !params[:passes_count].blank?
      day_pass_config = @account.day_pass_config
      passes_count = params[:passes_count].to_i
      raise "Maximum 30 Day passes can be extended at a time." if passes_count > 30
      day_pass_config.update_attributes(:available_passes => (day_pass_config.available_passes +  passes_count))
    end
    redirect_to :back
   end
  end

  def add_feature
    Sharding.select_shard_of(params[:account_id]) do 
      @account = Account.find(params[:account_id])
      if !@account.features?(params[:feature_name])
        feature = @account.features.send(params[:feature_name])
        if feature.create
          flash[:notice] = "Feature added"
        else
          flash[:notice] = "Unable to add feature"
        end
      else
        flash[:notice] = "Feature is already added for this account"
      end
    end
    redirect_to :back
  end

  def change_url
    old_url = params[:old_url]
    new_url = params[:new_url]
    new_account = DomainMapping.find_by_domain(new_url)
    unless new_account.nil?
      flash[:error] = "New account url is not available"
      redirect_to :back and return
    end
    Sharding.select_shard_of(old_url) do
      current_account = Account.find_by_full_domain(params[:old_url])
      email_configs = current_account.all_email_configs
      email_configs.each do |email_config|
        old_to_email = email_config.to_email
        new_to_email = old_to_email.sub old_url, new_url
        email_config.to_email = new_to_email

        old_reply_email = email_config.reply_email
        new_reply_email = old_reply_email.sub old_url, new_url
        email_config.reply_email = new_reply_email
        email_config.save
      end
      current_account.full_domain = new_url
      if current_account.save
        flash[:notice] = "Successfully changed the url"
      else
        flash[:notice] = "Unable to change url. Errors: #{current_account.errors.full_messages}"
      end
    end
    redirect_to :back
  end


  def check_super_admin_role
     unless current_user.has_role?(:manage_admin)
      flash[:notice] = "Not authorized to do this action!!!"
      redirect_to(admin_subscription_login_path)
    end
  end

  def check_admin_user_privilege
      if !(current_user and current_user.has_role?(:accounts))
        flash[:notice] = "You dont have access to view this page"
        redirect_to(admin_subscription_login_path)
      end
  end 

  def select_account_shard
    Sharding.select_shard_of(params[:id]) do 
      Sharding.run_on_slave do
        yield 
      end
    end
  end

end
