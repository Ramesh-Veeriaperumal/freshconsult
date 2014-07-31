class SubscriptionPaymentObserver < ActiveRecord::Observer
    
  def before_create(payment)
    set_info_from_subscription(payment)
    calculate_affiliate_amount(payment)
  end

  def after_create(payment)
    # send_receipt(payment)
    update_affiliate(payment) if payment.affiliate
    #add_to_crm(payment)
  end

  def after_commit_on_create(payment)
    add_to_crm(payment)
  end

  private

    def set_info_from_subscription(payment)
      payment.account = payment.subscription.account
      payment.affiliate = payment.subscription.affiliate
    end

    def calculate_affiliate_amount(payment)
      return unless payment.affiliate
      payment.affiliate_amount = payment.amount * payment.affiliate.rate
    end
    
    def send_receipt(payment)
      return unless payment.amount > 0

      if payment.setup?
        SubscriptionNotifier.setup_receipt(payment)
      elsif payment.misc?
        #SubscriptionNotifier.misc_receipt(payment) #Has been moved to subscription itself.
      else
        SubscriptionNotifier.charge_receipt(payment)
      end
      
      true
    end

    def update_affiliate(payment)
      make_api_call(payment) 
    end

    def make_api_call(payment)
      begin
        subscription = payment.subscription
        if subscription.subscription_payments.first.created_at > 1.year.ago
          response = HTTParty.get('https://shareasale.com/q.cfm', :query => {
              :amount => payment.amount,
              :tracking => payment.id,
              :transtype => "sale",
              :merchantID => SubscriptionAffiliate::AFFILIATES[:shareasale][:merchant_id],
              :userID => payment.affiliate.token })
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        FreshdeskErrorsMailer.error_email(nil,nil,e,{:subject => "Error contacting shareAsale #{payment.id}"})
      end
    end

    def add_to_crm(payment)
      Resque.enqueue(CRM::AddToCRM::PaidCustomer, {:account_id => payment.account_id, :item_id => payment.id})
    end
end

