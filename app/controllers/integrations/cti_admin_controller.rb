class Integrations::CtiAdminController < Admin::AdminController
  before_filter :feature_enabled?
  before_filter :load_app
  before_filter :check_other_cti_app
  before_filter :create_app, :only => [:edit]
  before_filter :check_iframe_size, :only => [:update]
  before_filter :check_iframe_url, :only => [:update]
  APP_NAME = Integrations::Constants::APP_NAMES[:cti]

  def edit
    used_cti_phones = @installed_app.cti_phones.where("agent_id is not null").includes(:agent)
    unused_cti_phones = @installed_app.cti_phones.where("agent_id is null")
    render :template => "integrations/applications/cti_admin_settings", :locals => {
             :application_name => @application.name,
             :used_cti_phones => used_cti_phones,
             :unused_cti_phones => unused_cti_phones
           }
  rescue => e
    Rails.logger.error "Problem in editing cti options. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in editing cti options. #{e.message}", :account_id => current_account.id}})
    flash[:error] = t(:'flash.application.install.error')
    redirect_to integrations_applications_path
  end


  def update
    begin
      @installed_app.set_configs params[:configs]
      if params[:configs][:cti_ctd_user_name].blank?
        @installed_app.configs[:inputs][:password] = ""
      end
      @installed_app.save!
      flash[:notice] = t(:'flash.application.update.success')
    rescue => e
      Rails.logger.error "Problem in updating cti_options. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in updating cti options. #{e.message}", :account_id => current_account.id}})
      flash[:error] = t(:'flash.application.update.error')
    end
    redirect_to integrations_applications_path
  end

  def add_phone_numbers
    begin
      numbers = params[:numbers_text].split("\n");
      numbers.select! { |n| n.present? }
      errored_numbers = []
      msg = "<strong>#{t("integrations.cti_admin.phone.add_number_success")}</strong>"
      ActiveRecord::Base.transaction do
        numbers.each do |number|
          begin
            number.strip!
            current_account.cti_phones.create!(:phone => RailsFullSanitizer.sanitize(number))
          rescue ActiveRecord::RecordNotUnique => e
            errored_numbers << number
          end
        end
      end
      if errored_numbers.present?
        msg = t("integrations.cti_admin.phone.add_number_warning") % {
          :original_length => numbers.length,
          :added_length => numbers.length - errored_numbers.length,
          :numbers => errored_numbers.join(", ")
        }
      end
      render :json => {:msg => "success", :notice => msg}, :status => :ok
    rescue Exception => e
      Rails.logger.error "Error in adding numbers. #{e.message} #{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error in adding numbers.  #{e.message}", :account_id => current_account.id}})
      render :json => {:error => t("integrations.cti_admin.phone.add_number_failure")}, :status => :bad_request
    end
  end

  def unused_numbers
    @phones = current_account.cti_phones.where("agent_id is null")
  end

  def delete_number
    number = current_account.cti_phones.where(:id => params[:number_id]).first
    if number.present?
      number.destroy
      render :json => {:msg => "success"}, :status => :ok
    else
      render :json => {:error => "Number not found"}, :status => :not_found
    end
  end

  private

  def feature_enabled?
    render_404 unless current_account.features?(:cti)
  end

  def load_app
    @application = Integrations::Application.find_by_name(APP_NAME)
    @installed_app = current_account.installed_applications.where(:application_id => @application.id).first
  end

  def check_iframe_size
    if(params[:configs][:softfone_enabled].to_bool)
      params[:configs][:cti_iframe_height] = params[:configs][:cti_iframe_height].to_i.to_s
      params[:configs][:cti_iframe_width] = params[:configs][:cti_iframe_width].to_i.to_s
    end
  end

  def check_iframe_url
    if(params[:configs][:softfone_enabled].to_bool)
      begin
        url = URI.parse(params[:configs][:cti_iframe_url])
        raise "invalid iframe url" unless url.kind_of?(URI::HTTP) || url.kind_of?(URI::HTTPS)
      rescue Exception => e
        Rails.logger.error "invalid url \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        flash[:error] = t(:'flash.application.update.error')
        redirect_to integrations_applications_path
      end
    end
  end

  def create_app
    unless @installed_app
      @installed_app = current_account.installed_applications.build(:application => @application)
      @installed_app.set_configs("softfone_enabled" => "0", "call_note_private" => "1", "click_to_dial" => "0")
      @installed_app.save!
    end
  end

  def check_other_cti_app
    if @application.cti?
      if current_account.cti_installed_app_from_cache && @installed_app.nil?
        flash[:notice] = t(:'flash.application.install.cti_error')
        redirect_to integrations_applications_path and return
      end
      if current_account.freshfone_active?
        flash[:notice] = t(:'flash.application.install.freshfone_alert')
        redirect_to :controller=> 'applications', :action => 'index'
        return
      end
    end
  end
end
