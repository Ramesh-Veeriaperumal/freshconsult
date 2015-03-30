class Admin::Ecommerce::EbayController < Admin::Ecommerce::AccountsController

  before_filter { |c| c.requires_feature :ecommerce }
  before_filter :load_account, :only => [:edit, :update, :destroy]

  def new
    @ebay_account = scoper.new
    @email_configs = scoper.pluck(:email_config_id)
  end

  def create
    @ebay_account = scoper.build(params[:ecommerce_ebay])
    @ebay_account.build_email_config(params[:email_config]) if params["email_configuration"].to_i.zero?
    if @ebay_account.save
      flash[:notice] = t('admin.ecommerce.new.account_created')
      redirect_to admin_ecommerce_accounts_path
    else
      flash[:error] = t(:'flash.general.create.failure', :human_name => t('admin.ecommerce.human_name'))
      render :new
    end
  end

  def instructions
  end

  def update
    if params["email_configuration"].to_i.zero?
        @ebay_account.build_email_config(params[:email_config])
        params[:ecommerce_ebay].delete(:email_config_id)
    end

    if @ebay_account.update_attributes(params[:ecommerce_ebay])
      flash[:notice] = t(:'flash.general.update.success', :human_name => t('admin.ecommerce.human_name'))
      redirect_to admin_ecommerce_accounts_path
    else
      flash[:error] = t(:'flash.general.update.failure', :human_name => t('admin.ecommerce.human_name'))
      render :edit
    end
  end

  def destroy
    if @ebay_account.destroy
      flash[:notice] = t(:'flash.general.destroy.success', :human_name => t('admin.ecommerce.human_name'))
    else
      flash[:error] = t(:'flash.general.destroy.failure', :human_name => t('admin.ecommerce.human_name'))
    end
    redirect_to admin_ecommerce_accounts_path
  end

  private
    def load_account
      @ebay_account = scoper.find(params[:id])
    end

    def scoper
      current_account.ebay_accounts
    end

end