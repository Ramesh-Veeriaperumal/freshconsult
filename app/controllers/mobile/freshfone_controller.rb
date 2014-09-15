class Mobile::FreshfoneController < ApplicationController

	def numbers
		render :json => {:freshfone_numbers => current_account.freshfone_numbers.map(&:as_numbers_mjson)}
	end
	
end
