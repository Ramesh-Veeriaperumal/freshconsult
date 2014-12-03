class Admin::Mobihelp::AppsController < Admin::AdminController


  before_filter :load_app, :only => [:edit, :update, :destroy]

  def index
    @applist = current_account.mobihelp_apps.find_all_by_deleted(false)
  end

  def new
    platform = params[:platform].to_i
    @app = Mobihelp::App.new
    @app.platform = platform
  end

  def create
    @app = current_account.mobihelp_apps.build(params[:mobihelp_app])
    @app.platform = @app.platform.to_i
    if @app.save
        flash[:notice] = t(:'flash.general.create.success', :human_name => t('admin.mobihelp.human_name'))
        redirect_to edit_admin_mobihelp_app_path(@app)
    else
      flash[:error] = t(:'flash.general.create.failure', :human_name => t('admin.mobihelp.human_name'))
      render :action => 'new'
    end
  end

  def edit

  end

  def update
    if @app.update_attributes(params[:mobihelp_app])
      flash[:notice] = t(:'flash.general.update.success', :human_name => t('admin.mobihelp.human_name'))
      redirect_to :action => 'index'
    else
      flash[:error] = t(:'flash.general.update.failure', :human_name => t('admin.mobihelp.human_name'))
      render 'edit'
    end
  end

  def destroy
    @app.deleted = true
    if @app.save
      flash[:notice] = t(:'flash.general.destroy.success', :human_name => t('admin.mobihelp.human_name'))
    else
      flash[:error] = t(:'flash.general.destroy.failure', :human_name => t('admin.mobihelp.human_name'))
    end
    respond_to do |format|
      format.html { redirect_to(admin_mobihelp_apps_path) }
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end

  private

    def load_app
      @app = current_account.mobihelp_apps.find(params[:id])
    end

end
