class SubscriptionAdmin::AccountsController < ApplicationController
 
  include AdminControllerMethods
  
  around_filter :select_account_shard, :only => [:show]
  before_filter :check_super_admin_role, :only => [:add_day_passes, :add_feature, :change_url, :block_account, :remove_feature, :change_account_name]


  def show
  	@account = Account.find(params[:id])    
  end
  
  def add_day_passes
   Sharding.admin_select_shard_of(params[:id]) do 
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
    Sharding.admin_select_shard_of(params[:account_id]) do 
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

  def remove_feature
    Sharding.admin_select_shard_of(params[:account_id]) do 
      @account = Account.find(params[:account_id])
      if @account.features?(params[:feature_name])
        feature = @account.features.send(params[:feature_name])
        if feature.destroy
          flash[:notice] = "Feature removed"
        else
          flash[:notice] = "Unable to remove feature"
        end
      else
        flash[:notice] = "The account doesn't have the feature - #{params[:feature_name]}"
      end
    end
    redirect_to :back
  end

  def change_account_name
    Sharding.admin_select_shard_of(params[:account_id]) do
       @account = Account.find(params[:account_id])
       @account.name = params[:account_name]
       if @account.save
          flash[:notice] = "Successfully changed"
        else
          flash[:notice] = "Unable to change the name, Errors:: #{@account.errors}"
        end
    end
    redirect_to :back
  end

  def change_currency #Have to verify with pappu
    Sharding.admin_select_shard_of(params[:account_id]) do
      a = Account.find(params[:account_id])
      s = a.subscription
      s.currency = Subscription::Currency.find_by_name(params[:new_currency])
      s.state = "active"
      s.save!
    end
  end

  def ublock_account
    FreshdeskErrorsMailer.deliver_unblock_notification(params.merge({ :email => current_user.email, :recipients => "hariharan.r@freshdesk.com"}))
    shard_mapping = ShardMapping.find(params[:account_id])
    shard_mapping.status = ShardMapping::STATUS_CODE[:ok]
    shard_mapping.save
    Sharding.admin_select_shard_of(params[:account_id]) do 
      @account = Account.find(params[:account_id])
      @account.make_current
      sub = @account.subscription
      sub.state="trial"
      sub.save
      Account.reset_current_account
    end
    $spam_watcher.set("#{params[:account_id]}-","true")
    redirect_to :back
  end

  def block_account
    shard_mapping = ShardMapping.find(params[:account_id])
    shard_mapping.status = ShardMapping::STATUS_CODE[:not_found]
    shard_mapping.save
    Sharding.admin_select_shard_of(params[:account_id]) do 
      @account = Account.find(params[:account_id])
      @account.make_current
      sub = @account.subscription
      sub.state="suspended"
      sub.save
      Account.reset_current_account
    end
    $spam_watcher.del("#{params[:account_id]}-")
    redirect_to :back   
  end

  def whitelist
    $spam_watcher.set("#{params[:account_id]}-","true")
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
    Sharding.admin_select_shard_of(old_url) do
      current_account = Account.find_by_full_domain(params[:old_url])
      current_account.make_current
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
    Sharding.admin_select_shard_of(params[:id]) do 
      Sharding.run_on_slave do
        yield 
      end
    end
  end

end
