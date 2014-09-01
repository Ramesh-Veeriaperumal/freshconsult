class AccountConfigurationsController < ApplicationController

	def update
		account_configuration = current_account.account_configuration

		if(account_configuration.update_attributes(params[:account_configuration]))
			flash[:notice] = I18n.t('success_msg')
		else
			flash[:notice] = I18n.t('failure_msg')
		end		

		redirect_back_or_default account_url
	end

end