class Admin::DayPassesController < ApplicationController
  
  before_filter :set_selected_tab
  before_filter :load_config
  before_filter :load_purchases, :only => [:index]
  before_filter :check_params, :only => [:day_pass_history_filter]
  
  
  def index
    @day_pass_amounts = DayPassUsage::DAYPASS_QUANTITY.map{ |pass| 
      [pass, (pass * subscription.retrieve_addon_price(:day_pass)).to_i] 
    }
    @selected_filter = {:user_name => t("admin.day_passes.index.all"), :end_day => DayPassUsage::DAYS_FILTER.first}
    @daypass_history = scoper.filter_passes(DayPassUsage::DAYS_FILTER.first).paginate(
                                                              :page => params[:page], :per_page =>10)
  end
  
  def update
    if DayPassUsage::DAYPASS_QUANTITY.include?(params[:day_pass_config][:recharge_quantity].to_i)
      @day_pass_config.update_attributes(params[:day_pass_config])
    end
    if request.xhr?
      render :json => 200
    else
      redirect_to admin_day_passes_path
    end
  end
  
  def toggle_auto_recharge
    @day_pass_config.toggle!(:auto_recharge)
    redirect_to admin_day_passes_path
  end
  
  def buy_now 
    if DayPassUsage::DAYPASS_QUANTITY.include?(params[:quantity].to_i) and @day_pass_config.buy_now(params[:quantity].to_i)
      flash[:notice] = t("flash.daypass.success", :quantity => params[:quantity])
    else
      flash[:error] = t("flash.daypass.failed")
    end
    
    redirect_to admin_day_passes_path
  end

  def day_pass_history_filter
    @selected_filter = {:user_id => params[:agent_id], :user_name => params[:agent_name], :end_day => params[:end_day]}
    @daypass_history = scoper.filter_passes(params[:end_day], params[:agent_id]).paginate(:page => params[:page], :per_page =>10)
  end
  
  private
    def load_config
      @day_pass_config = current_account.day_pass_config
    end
    
    def subscription
      current_account.subscription
    end
    
    def load_purchases
      @day_pass_purchases = current_account.day_pass_purchases.all(:include => :payment)
    end
  
    def set_selected_tab
      @selected_tab = :admin
    end

    def check_params
      params[:end_day] = DayPassUsage::DAYS_FILTER.first unless DayPassUsage::DAYS_FILTER.include?(params[:end_day].to_i)
    end

    def scoper
      current_account.day_pass_usages
    end

end
