class SubscriptionAdmin::AccountsController < ApplicationController
 
  include AdminControllerMethods
  
  around_filter :select_account_shard, :only => [:show]


  def show
  	@account = Account.find(params[:id])
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
    render :action => 'show'
   end
  end

  def add_freshfone_credits
    Sharding.select_shard_of(params[:id]) do 
      @account = Account.find(params[:id])
      if request.post? and !params[:freshfone_credits].blank?
        freshfone_credit = Freshfone::Credit.find_or_create_by_account_id(@account)
        credit = params[:freshfone_credits].to_i
        freshfone_credit.update_attributes(:available_credit => (freshfone_credit.available_credit +  credit))
        Rails.logger.info "ADDED $#{credit} FRESHFONE CREDITS FOR ACCOUNT ##{@account.id}-#{@account}"
      end
      redirect_to :action => "show"
    end
  end

  def toggle_freshfone
    Sharding.select_shard_of(params[:id]) do 
      @account = Account.find(params[:id])
      if feature?(:freshfone)
        @account.features.freshfone.destroy
      else
        @account.features.freshfone.create
      end
      redirect_to :action => "show"
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
