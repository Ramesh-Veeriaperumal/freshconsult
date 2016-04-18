class Admin::DayPassesController < ApplicationController
  
  before_filter :set_selected_tab
  before_filter :load_config
  before_filter :load_purchases, :only => [:index]
  DAYPASS_QUANTITY = [5, 10, 25, 50]
  
  def index
    @day_pass_amounts = DAYPASS_QUANTITY.map{ |pass| 
      [pass, (pass * subscription.retrieve_addon_price(:day_pass)).to_i] 
    }
  end
  
  def update
    if DAYPASS_QUANTITY.include?(params[:day_pass_config][:recharge_quantity].to_i)
      @day_pass_config.update_attributes(params[:day_pass_config])
    end
    redirect_to admin_day_passes_path
  end
  
  def toggle_auto_recharge
    @day_pass_config.toggle!(:auto_recharge)
    redirect_to admin_day_passes_path
  end
  
  def buy_now 
    if DAYPASS_QUANTITY.include?(params[:quantity].to_i) and @day_pass_config.buy_now(params[:quantity].to_i)
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
    
    def subscription
      current_account.subscription
    end
    
    def load_purchases
      @day_pass_purchases = current_account.day_pass_purchases.all(:include => :payment)
  end
  
   def set_selected_tab
        @selected_tab = :admin
    end

end
