class Admin::Ecommerce::AccountsController < Admin::AdminController

	before_filter { |c| c.requires_feature :ecommerce }
	before_filter :check_account_limit, :only => [:new, :create]

	def index
		@ecommerce_accounts = scoper
	end

	 private

    def check_account_limit 
      if scoper.count >= Ecommerce::Constants::MAX_ECOMMERCE_ACCOUNTS
        flash[:notice] = t('admin.ecommerce.limit_exceed')
        redirect_to admin_ecommerce_accounts_path and return
      end
    end

    def scoper
    	current_account.ecommerce_accounts
    end
end
