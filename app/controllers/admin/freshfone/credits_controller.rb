class Admin::Freshfone::CreditsController < ApplicationController
	before_filter { |c| c.requires_feature :freshfone }
	before_filter :load_freshfone_credit
	before_filter :set_freshfone_credit, :only => [:purchase]
  before_filter :validate_freshfone_credit, :only => [:purchase]

	def purchase
		if @freshfone_credit.purchase
      flash[:notice] = t('flash.freshfone.credits.success')
    else
      flash[:error] = t('flash.freshfone.credits.error')
    end
    redirect_to subscription_url
	end

	def enable_auto_recharge
    @freshfone_credit.enable_auto_recharge(params[:recharge_quantity].to_i)
    redirect_to subscription_url
  end

  def disable_auto_recharge
  	@freshfone_credit.disable_auto_recharge
  	redirect_to subscription_url
  end

	private
		def load_freshfone_credit
			@freshfone_credit = Freshfone::Credit.find_or_create_by_account_id(current_account.id)
		end

		def set_freshfone_credit
			@freshfone_credit.selected_credit = params[:credit].to_i
		end

    def validate_freshfone_credit
      unless @freshfone_credit.valid_recharge_amount?
        flash[:notice] = I18n.t('flash.freshfone.credits.invalid_recharge_amount') 
        redirect_to subscription_url
      end
    end
end