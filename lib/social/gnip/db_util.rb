module Social::Gnip::DbUtil

	include Social::Gnip::Constants
	
  #Bulk update of twitter handles when their rule_tag changes
  def bulk_update_twitter_handles(rule_tag, response , new_rule_tag = nil)
    tag_array = rule_tag.split(DELIMITER[:tags])
    tag_array.each do |gnip_tag|
      tag = Social::Gnip::RuleTag.new(gnip_tag)
      args = {
        :account_id => tag.account_id,
        :twitter_handle_id => tag.handle_id
      }
      Sharding.select_shard_of(tag.account_id) do
        account = Account.find_by_id(tag.account_id)
        account.make_current if account
      end
      account = Account.current
      handle = account.twitter_handles.find_by_id(tag.handle_id)
      unless response
        params = {
          :handle => handle,
          :action => RULE_ACTION[:delete],
          :response => false
        }
        update_db(params)
        requeue(args)
      else
        handle.update_attribute(:rule_tag, new_rule_tag) if handle
      end
    end
  end
  
  #update db for rule_value, rule_tag, rule_state
  def update_db(params)
    update_rule(params[:handle], params[:rule_value], params[:rule_tag])
    update_rule_state(params[:handle], params[:action], params[:response])
  end
   
   
  private
   
	  def update_rule(handle, value, tag)
	    handle.update_attributes(:rule_value => value, :rule_tag => tag) if handle && !@replay
	  end
	  
	  def update_rule_state(handle, action, response)
	    rule_state = @replay ? Social::TwitterHandle::GNIP_RULE_STATES_KEYS_BY_TOKEN[:replay] :
	                         Social::TwitterHandle::GNIP_RULE_STATES_KEYS_BY_TOKEN[:production]
	    return unless handle
	    
	    if action == RULE_ACTION[:add] && response
	      handle.update_attribute(:gnip_rule_state, (handle.gnip_rule_state | rule_state))
	    elsif action == RULE_ACTION[:delete]
	      if handle.gnip_rule_state & rule_state
	        handle.update_attribute(:gnip_rule_state, (handle.gnip_rule_state - rule_state))
	      end
	    end
	  end
end
