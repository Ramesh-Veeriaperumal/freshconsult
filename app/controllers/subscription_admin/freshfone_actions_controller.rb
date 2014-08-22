class SubscriptionAdmin::FreshfoneActionsController < ApplicationController
  include AdminControllerMethods

  around_filter :select_shard, :except => [:index]
  before_filter :validate_credits, :only => [:add_credits]
  before_filter :validate_freshfone_action, :only => [:process_freshfone_account]
  before_filter :notify_freshfone_ops, :except => [:index]

  def add_credits
    @freshfone_credit = @account.freshfone_credit
    @freshfone_credit.present? ? update_credits : create_credits
    redirect_to admin_account_path(@account) 
  end

  def refund_credits
    if @account.freshfone_account.blank?
      @account.freshfone_credit.destroy if @account.freshfone_credit.present?
      payments = @account.freshfone_payments
      payments.update_all(:status_message => "refunded")
      flash[:notice] = "Successfully refunded Freshfone credits"
      redirect_to admin_account_path(@account)
    else
      flash[:notice] = "Cannot refund. Freshfone account already activated"
      redirect_to :back
    end
  end 

  def port_ahead
    display_number = params[:display_number] || params[:number]

    freshfone_number = @account.freshfone_numbers.create(:number_sid => params[:sid], 
      :number => params[:number], :display_number => display_number, 
      :country => "US", :number_type => params[:number_type], :skip_in_twilio => true)

    flash[:notice] = "Freshfone number successfully created"
    redirect_to :back
  end

  def post_twilio_port
    begin
      freshfone_number = @account.freshfone_numbers.create(params[:number_attributes])
      if freshfone_number.new_record?
        error_messages = (freshfone_number.errors.any?) ? 
                          freshfone_number.errors.full_messages.to_sentence : ""
        flash[:notice] = "Number creation failed. #{error_messages}"
      else
        flash[:notice] = "Freshfone number successfully created"
      end  
    rescue Exception => e
      flash[:notice] = "Number creation failed. #{e.message}"
    end
    redirect_to :back
  end

  def suspend_freshfone
    @account.freshfone_account.suspend
    flash[:notice] = "Freshfone Account suspended"
    redirect_to :back
  end

  def account_closure
    freshfone_account = @account.freshfone_account
    if freshfone_account.suspended?
      twilio_subaccount = TwilioMaster.client.accounts.get(freshfone_account.twilio_subaccount_id)
      twilio_subaccount.incoming_phone_numbers.list.each do |number|
        number.delete
      end
      @account.freshfone_numbers.each do |number|
        number.deleted = true
        number.send(:update_without_callbacks)
      end
    end

    flash[:notice] = "Freshfone Account closure processed successfully"
    redirect_to :back
  end

  private
    def update_credits
      if @freshfone_credit.increment!(:available_credit, params[:credits].to_i)
        create_payment params[:credits]
        flash[:notice] = "Succesfully updated Freshfone credits"
      end
    end

    def create_credits
      @account.create_freshfone_credit(:available_credit => params[:credits])
      create_payment params[:credits]
      flash[:notice] = "Successfully added Freshfone credits"
    end

    def create_payment(credits)
      status_message = params[:status_message] || "promotional"
      @account.freshfone_payments.create(:status_message => status_message, 
          :purchased_credit => credits, :status => true)
    end

    def validate_credits
      if (params[:credits].blank? || params[:credits].to_i > 100)
        flash[:notice] = "Invalid credit"
        redirect_to :back
      end
    end

    def validate_freshfone_action
      freshfone_action = params[:freshfone_action]
      if freshfone_action.blank?
        flash[:notice] = "Select a valid action"
        redirect_to :back
      else
        send freshfone_action if respond_to? freshfone_action
      end
    end

    def notify_freshfone_ops
      type = params[:action].humanize
      subject = "admin.freshdesk : #{type} for Account #{@account.id}"
      message = "#{type} for account #{@account.id} by #{current_user.name}<#{current_user.email}>"
      FreshfoneNotifier.deliver_freshfone_email_template(@account, {
        :subject => subject,
        :recipients => FreshfoneConfig['ops_alert']['mail']['to'],
        :from => FreshfoneConfig['ops_alert']['mail']['from'],
        :message => message
      })
    end

    def select_shard
      head :ok if (params[:account_id].blank? && !request.post?)
      Sharding.select_shard_of(params[:account_id]) do 
        @account = Account.find(params[:account_id])
        yield
      end
    end

    def check_admin_user_privilege
      if !(current_user && current_user.has_role?(:freshfone))
        flash[:notice] = "You dont have access to view this page"
        redirect_to(admin_subscription_login_path)
      end
    end 
end