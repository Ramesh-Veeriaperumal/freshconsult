class Admin::Marketplace::ExtensionsController <  Admin::AdminController
  include Marketplace::ApiMethods
  include Marketplace::ApiUtil
  include Marketplace::HelperMethods
  include SubscriptionsHelper
  include ActionView::Helpers::NumberHelper
  
  before_filter :categories, :only => [:index, :search]
  before_filter :validate_subscription, :only => [:payment_info]
  before_filter :extension, :only => [:show, :payment_info]
  before_filter(:only => [:custom_apps]) { |c| c.requires_this_feature :custom_apps }

  rescue_from Exception, :with => :mkp_exception

  def index
    if params[:sort_by]
      @extensions = Hash.new
      params[:sort_by].each do |sort_key| 
        @extensions[sort_key.to_sym] = mkp_extensions(sort_key).body
        render_error_response and return if error_status?(mkp_extensions(sort_key))
      end
    else
      @extensions = mkp_extensions.body
      render_error_response and return if error_status?(mkp_extensions)
    end
  end

  def custom_apps
    extensions = mkp_custom_apps
    render_error_response and return if error_status?(extensions)
    @extensions = extensions.body.sort_by { |ext| ext['display_name'].downcase }
    render 'admin/marketplace/extensions/custom_apps'
  end

  def show
    inst_status = install_status
    render_error_response and return if error_status?(inst_status)
    @install_status = inst_status.body
    @is_oauth_app = true if @extension['features'] && @extension['features'].include?('oauth')
  end

  def search
    extensions = search_mkp_extensions
    render_error_response and return if error_status?(extensions)
    @extensions = extensions.body
    render 'admin/marketplace/extensions/index'
  end

  def auto_suggest
    extensions = auto_suggest_mkp_extensions
    render_error_response and return if error_status?(extensions)
    @auto_suggestions = extensions.body
    render 'admin/marketplace/extensions/auto_suggest'
  end

  def payment_info
    @addon_details = @extension['addon']['metadata'].find { |data| data['currency_code'] == current_account.currency_name }
    render :json => { 
      :message => I18n.t(@addon_details['trial_period'].blank? ? 'marketplace.payment_ok' : 'marketplace.payment_trial_info',
      :trial_period => @addon_details['trial_period'],
      :price => format_amount(@addon_details['price'], @addon_details['currency_code']),
      :estimate => estimate_addon_price,
      :addon_type => addon_type,
      :payment_ok_btn => render_to_string( :inline => is_ni? ? "<%= link_to t('ok'), params['install_url'],
        :class => 'btn btn-default btn-primary payment-btn nativeapp', :method => :post %>"
        : "<%= link_to t('ok'), '#', 'data-url' => params['install_url'],
        :class => 'btn btn-default btn-primary payment-btn install-form-btn' %>"))
    }
  end

  private

    def validate_subscription
      if current_account.subscription.card_number.blank?
        msg = ''
        msg << I18n.t('marketplace.no_payment_info')
        msg << %(<a href='#{billing_subscription_path}' class='btn btn-default btn-primary payment-btn update-payment-info' target='_blank'>)
        msg << I18n.t('marketplace.update_payment_info')
        msg << %(</a>)
        render :json => { :message =>  msg }
      end
    end

    def estimate_addon_price
      estimate_price = @addon_details['price'].to_f * current_account.subscription.renewal_period * app_units_count
      return format_amount(estimate_price, @addon_details['currency_code'])
    end
end
