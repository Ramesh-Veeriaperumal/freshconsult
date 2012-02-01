module HandleAdditionalAgent
  
  def charge_agent_prorata
   @user = @agent.user unless @user
   if @user.valid? and !@agent.occasional? and current_account.reached_agent_limit?
    sub = current_account.subscription
    sub.agent_limit = sub.agent_limit + 1 if sub.active?
     unless sub.save
       flash[:notice] = t('unable_to_charge')
       redirect_to :back
     end  
   end
  end

end