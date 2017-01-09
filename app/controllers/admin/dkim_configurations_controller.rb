class Admin::DkimConfigurationsController < Admin::AdminController
  
  include Dkim::Methods
  
  before_filter :check_feature
  before_filter :load_domain_category, :check_account_state, :except => [:index]

  DEFAULT_MINUTES = 15.minutes
  MAX_CAP = 6.hours

  def index
    @domain_categories = scoper.active_domains.paginate(:page => params[:page], :per_page =>10)
  end

  def create
    if @domain_category
      result = Dkim::ConfigureDkimRecord.new(@domain_category).build_records
    end
    flash[:notice] = t('email_configs.dkim.config_fail') unless @domain_category.status == OutgoingEmailDomainCategory::STATUS['unverified']
    render :action => :verify_email_domain
  end

  def verify_email_domain
    Dkim::ValidateDkimRecord.new(@domain_category).validate if @domain_category.present?
    Rails.logger.debug "verify_email_domain result ::: #{@domain_category.inspect}"
    if domain_unverified?
      set_others_redis_key(dkim_verify_key(@domain_category), Time.now, 48.hours)

      DkimRecordVerificationWorker.perform_at(DEFAULT_MINUTES.from_now, {:account_id => current_account.id, 
        :record_id => @domain_category.id})
      
      flash[:notice] = t('email_configs.dkim.verify_fail')
    elsif @domain_category.status == OutgoingEmailDomainCategory::STATUS['active']
      remove_others_redis_key(dkim_verify_key(@domain_category))
    end
  end

  def remove_dkim_config
    @domain_category.status = OutgoingEmailDomainCategory::STATUS['delete']
    if @domain_category.save
      DkimRecordDeletionWorker.perform_async({:domain_id => @domain_category.id, :account_id => current_account.id})
      flash[:notice] = t('email_configs.dkim.remove_success')
    else
      flash[:notice] = t('email_configs.dkim.remove_fail')
    end
    redirect_to :action => :index
  end

  private

    def check_account_state
      redirect_to subscription_path unless current_account.active?
    end

    def load_domain_category
      @domain_category = scoper.find_by_id(params[:id])
    end
    
    def domain_unverified?
      @domain_category.status == OutgoingEmailDomainCategory::STATUS['unverified'] and @domain_category.last_verified_at > MAX_CAP.ago
    end
    
    def check_feature
      redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) unless current_account.dkim_enabled?
    end
end
