class Admin::FreshchatController < Admin::AdminController

  before_filter :load_item, :load_profile

  def create
    flash[:notice] = I18n.t('failure_msg') unless create_item
    render :index
  end

  def update
    flash[:notice] = I18n.t('failure_msg') unless update_item
    render :index
  end

  def toggle
    render :json => update_item
  end

  private
    def load_item
      @item = current_account.freshchat_account || Freshchat::Account.new
    end

    def load_profile
      @profile = current_user.agent
    end

    def update_item
      # params[:freshchat_account][:preferences] = @item.preferences.merge(params[:freshchat_account][:preferences]) if params[:freshchat_account][:preferences]
      @item.update_attributes(permitted_params)
    end

    def create_item
      @item = Freshchat::Account.create(permitted_params)
    end

    def permitted_params
      params[:freshchat_account].permit(:app_id, :enabled, :portal_widget_enabled, :token)
    end
end
