class Freshfone::AddressController < ApplicationController
  include Freshfone::FreshfoneUtil
  def create
    render :json => {
      :success => build_address.save, 
      :errors => @freshfone_address.errors.full_messages
    }
  end

  def inspect
    render :json => {
      :isExist => is_already_exist?
    }
  end

  private

    def build_address
      create_subaccount(current_account) if new_freshfone_account?(current_account)
      @freshfone_address = current_account.freshfone_account.freshfone_addresses.new(
        :friendly_name => params[:business_name],
        :business_name => params[:business_name],
        :address => params[:address],
        :city => params[:city],
        :state => params[:state],
        :postal_code => params[:postal_code],
        :country => params[:country]
      )
    end

    def is_already_exist?
      ff_account = current_account.freshfone_account
      ff_account.present? && ff_account.freshfone_addresses.find_by_country(params[:country]).present?
    end
end