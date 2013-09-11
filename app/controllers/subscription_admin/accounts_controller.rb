class SubscriptionAdmin::AccountsController < ApplicationController
  include ModelControllerMethods
  include AdminControllerMethods
  include ReadsToSlave
  
  skip_before_filter :check_account_state
  around_filter :select_shard, :only => [:show,:add_day_passes]
  skip_filter :run_on_slave, :only => [:add_day_passes]


  def show
  	@account = Account.find(params[:id])
  end
  
  def add_day_passes
    @account = Account.find(params[:id])
    if request.post? and !params[:passes_count].blank?
      day_pass_config = @account.day_pass_config
      passes_count = params[:passes_count].to_i
      raise "Maximum 30 Day passes can be extended at a time." if passes_count > 30
      day_pass_config.update_attributes(:available_passes => (day_pass_config.available_passes +  passes_count))
      Rails.logger.info "ADDED #{passes_count} DAY PASSES FOR ACCOUNT ##{@subscription.account_id}-#{@subscription.account}"
    end
    render :action => 'show'
  end

  def select_shard
    Sharding.select_shard_of(params[:id]) do 
      Sharding.run_on_slave do
        yield 
      end
    end
  end

end
