class Admin::DayPassesController < Admin::AdminController
  before_filter :load_config
  before_filter :load_purchases, :only => [:index]
  
  def index
    @day_pass_amounts = [5, 10, 25, 50].map{ |pass| [pass, (pass * get_plan.day_pass_amount).to_i] }
  end
  
  def update
    @day_pass_config.update_attributes(params[:day_pass_config])
    redirect_to admin_day_passes_path
  end
  
  def toggle_auto_recharge
    @day_pass_config.update_attributes(:auto_recharge => !@day_pass_config.auto_recharge)
    redirect_to admin_day_passes_path
  end
  
  def buy_now 
    if @day_pass_config.buy_now(params[:quantity].to_i)
      flash[:notice] = t("flash.daypass.success", :quantity => params[:quantity])
    else
      flash[:error] = t("flash.daypass.failed")
    end
    
    redirect_to admin_day_passes_path
  end
  
  private
    def load_config
      @day_pass_config = current_account.day_pass_config
    end
    
    def get_plan
      current_account.subscription.subscription_plan
    end
    
    def load_purchases
      @day_pass_purchases = current_account.day_pass_purchases
    end

end
