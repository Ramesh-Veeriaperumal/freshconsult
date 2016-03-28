class Freshfone::CallerIdController < ApplicationController
  
  include Freshfone::FreshfoneUtil
  include Freshfone::Endpoints
  
  skip_before_filter :check_privilege, :only => [:add]
  before_filter :check_if_caller_id_verified, :only => [:validation]
  before_filter :load_caller_id, :only => [:delete]
  
  def validation
    begin
      outgoing_caller = twilio_account.outgoing_caller_ids.create(
                                    :phone_number => params[:number],
                                    :status_callback => caller_id_status_verification_url)   
      render :json => {:code => outgoing_caller.validation_code , :phone_number => outgoing_caller.phone_number}                                                          
    rescue Twilio::REST::RequestError => e
      render :json => { :error_message => error_message(e.code) } 
    end    
  end

  def add
    current_account.freshfone_caller_id.create({:number => params[:To],
      :number_sid => params[:OutgoingCallerIdSid]}) if params[:VerificationStatus] == "success"
    respond_to do |format|
      format.html { render :nothing => true }
    end

  end

  def verify
    if outgoing_caller(params[:number])
      render :json => { :caller => outgoing_caller(params[:number]) }
    else
      render :json => { :caller => nil }
    end
  end

  def delete
    if @outgoing_caller
      @outgoing_caller.destroy
      render :json => {:deleted => true, :id => params[:caller_id]}
    else
      render :json => {:deleted => false }
    end
  end

  private
    
    def twilio_account
      current_account.freshfone_account.freshfone_subaccount
    end

    def outgoing_caller(number)
      current_account.freshfone_caller_id.find_by_number(number)
    end 

    def load_caller_id
      @outgoing_caller = current_account.freshfone_caller_id.find(params[:caller_id]) if params[:caller_id]
    end

    def check_if_caller_id_verified
      render :json => { :error_message => I18n.t('freshfone.admin.numbers.caller_id.twilio_errors.already_verified') } and return if outgoing_caller(formatted_number(params[:number]))
    end

    def formatted_number(number)
      return "+#{number.gsub(/[^\d]/, '')}"
    end

    def error_messages
      Freshfone::CallerId::ERROR_MESSAGES
    end

    def error_message(error_code)
      return error_messages[error_code] if error_messages[error_code].present?
      error_messages[:Default]
    end
end
