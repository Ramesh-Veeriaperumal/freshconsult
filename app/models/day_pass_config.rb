class DayPassConfig < ActiveRecord::Base
  self.primary_key = :id
  belongs_to :account
  
  RECHARGE_THRESHOLD = 2
  
  attr_protected :account_id
  
  def grant_day_pass(user, params)
    #Need to revisit about the right place.
    send_later(:try_auto_recharge) if available_passes <= RECHARGE_THRESHOLD
    
    if available_passes > 0
      #1. Decrement available passes in day_pass_configs.
      connection.execute("update day_pass_configs set available_passes=(available_passes - 1) where id=#{id}")

      #2. Extract useful params. Useless stuff with the current approach.
      usage_info = { :params => { :controller => params["controller"], 
          :action => params["action"]  } }
      usage_info[:params][:id] = params[:id] if params[:id]
      
      #3. Create the day pass and return
      Time.zone = user.time_zone #fix for first time logging users in order to avoid taking account time zone 
                                 #for cases where both of them are different      
      user.account.day_pass_usages.create( :granted_on => DayPassUsage.start_time, 
            :user => user, :usage_info => usage_info )
    end
  end
  
  def try_auto_recharge
    return unless (auto_recharge && available_passes <= RECHARGE_THRESHOLD && 
        account.subscription.active?)
    
    buy_now recharge_quantity
  end
  
  def buy_now(quantity)
    begin
      response = Billing::Subscription.new.buy_day_passes(account, quantity)
    rescue Exception => e
      failed_purchase(quantity, e)
    end

    if response
      connection.execute(
        %(update day_pass_configs set available_passes = 
        (available_passes + #{ActiveRecord::Base.sanitize(quantity)}) where id=#{id}))
        
      account.day_pass_purchases.create(
        :paid_with => DayPassPurchase::PAID_WITH[:credit_card],
        :status => DayPassPurchase::STATUS[:success],
        :quantity_purchased => quantity
      )
    end

    response
  end

  def failed_purchase(quantity, error)
    account.day_pass_purchases.create(
        :paid_with => DayPassPurchase::PAID_WITH[:credit_card],
        :status => DayPassPurchase::STATUS[:failure],
        :quantity_purchased => quantity,
        :status_message => error.error_code
      )
  end
  
end
