module HandleAdditionalAgent
  
  def charge_agent_prorata
   @user = @agent.user unless @user
   if @user.valid? and !@agent.occasional? and current_account.reached_agent_limit?
    sub = current_account.subscription
    sub.agent_limit = sub.agent_limit + 1 if sub.active?
     unless sub.save
       flash[:notice] = "Unable to charge the card for the added agent!"
       redirect_to :back
     end  
   end
  end

end