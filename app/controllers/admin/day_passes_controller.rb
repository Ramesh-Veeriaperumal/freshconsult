class Admin::DayPassesController < Admin::AdminController
  before_filter :load_config
  
  def index
  end
  
  def update
    
  end
  
  def buy_now
    if @day_pass_config.buy_now(params[:quantity].to_i)
      flash[:notice] = "Success" #Do i18n and change the text.
    else
      flash[:error] = "Failed"
    end
    
    redirect_to admin_day_passes_path
  end
  
  private
    def load_config
      @day_pass_config = current_account.day_pass_config
    end

end
