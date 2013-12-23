class Freshfone::BlacklistNumberController < ApplicationController

	def create
		number = current_account.freshfone_blacklist_numbers.build({
								:number => "+#{params['blacklist_number']['number']}" })
		if number.save
			flash[:notice] = t('flash.freshfone.number.add_blacklist_success')
		else
			flash[:notice] = t('flash.freshfone.number.add_blacklist_failure')
		end
		redirect_to freshfone_call_history_index_path
	end

	def destroy
		blacklist_number = current_account.freshfone_blacklist_numbers.find_by_number(params[:id])
		if blacklist_number.destroy
			flash[:notice] = t('flash.freshfone.number.remove_blacklist_success')
		else
			flash[:notice] = t('flash.freshfone.number.remove_blacklist_failure')
		end
		redirect_to freshfone_call_history_index_path
	end

end