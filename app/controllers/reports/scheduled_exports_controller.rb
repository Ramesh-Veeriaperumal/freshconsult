class Reports::ScheduledExportsController < ApplicationController
  include ModelControllerMethods
  include Reports::ScheduledExport::Constants

  before_filter :access_denied, :unless => :require_feature_and_privilege
  before_filter :has_activity_export_feature_and_privilege?, :load_activity_export, :only => [:edit_activity, :update_activity]
  before_filter :set_selected_tab

  def index
    @scheduled_ticket_export = false
    load_activity_export if has_activity_export_feature_and_privilege?
  end

  def edit_activity
    @api_url = ACTIVITY_EXPORT_API % {domain: current_account.domain}
  end

  def update_activity
    if @scheduled_activity_export.update_attributes(params[:scheduled_activity_export])
      flash[:notice] = I18n.t(:'flash.general.update.success', :human_name => human_name)
      redirect_back_or_default redirect_url
    else
      render :action => 'edit_activity'     
    end
  end

  protected

    def load_activity_export 
      @scheduled_activity_export = current_account.activity_export_from_cache if current_account.activity_export_from_cache.present?
      @scheduled_activity_export ||= current_account.build_activity_export(DEFAULT_ATTRIBUTES)
    end

    def require_feature_and_privilege
      has_activity_export_feature_and_privilege?
    end

    def has_activity_export_feature_and_privilege?
      current_account.ticket_activity_export_enabled? && privilege?(:manage_account)
    end

    def set_selected_tab
      @selected_tab = :reports
    end

end