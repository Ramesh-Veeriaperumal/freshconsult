class Freshfone::BlacklistNumberController < ApplicationController

	def create
		@blacklist_number = current_account.freshfone_blacklist_numbers.build({
								:number => params['blacklist_number']['number']})
		if @blacklist_number.save
			flash[:notice] = t('flash.freshfone.number.add_blacklist_success')
		else
			flash[:notice] = t('flash.freshfone.number.add_blacklist_failure')
		end
		respond_to do |format|
			format.js { }
		end
	end

	def destroy
		blacklist_number = current_account.freshfone_blacklist_numbers.find_by_number(params[:id])
		if blacklist_number.destroy
			flash[:notice] = t('flash.freshfone.number.remove_blacklist_success')
		else
			flash[:notice] = t('flash.freshfone.number.remove_blacklist_failure')
		end
		respond_to do |format|
			format.js { }
		end
	end

end