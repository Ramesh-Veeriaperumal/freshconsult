module Freshfone::NodeEvents

	include Redis::RedisKeys
	include Redis::IntegrationsRedis
	include ApplicationHelper
	include ActionView::Helpers::TagHelper
	include ActionView::Helpers::AssetTagHelper

	def unpublish_live_call(params)
    key = NEW_CALL % {:account_id => current_account.id}
    channel = FRESHFONE_CHANNEL % {:account_id => current_account.id}
    message = {:type => "completed_call"}
    remove_value_from_set(key, [called_entity])
    publish_to_channel(channel, message.to_json)
  end

  def publish_live_call(params)
    key = NEW_CALL % {:account_id => current_account.id}
    channel = FRESHFONE_CHANNEL % {:account_id => current_account.id}
    message = {:type => "new_call", :agent => called_entity}
    add_to_set(key, [called_entity])
    publish_to_channel(channel, message.to_json)
  end

  def add_active_call_params_to_redis(params, message=nil) #remove key on unpublish
    agent = (current_user.blank?) ? current_account.users.find(params[:agent]) : current_user
    active_call_key = ACTIVE_CALL % {:call_sid => params[:CallSid]}
    active_call_message = message || {
                                        :agent => agent.id, 
                                        :requester => params[:From],
                                        :call_sid => params[:CallSid], 
                                        :original_status => agent.freshfone_user_presence
                                      }
    set_key(active_call_key, active_call_message.to_json)
  end

	def publish_freshfone_presence(user, deleted=false)
		key = AGENT_AVAILABILITY % {:account_id => user.account_id}
		channel = FRESHFONE_CHANNEL % {:account_id => user.account_id}
		if !deleted && user.freshfone_user_online?
			message = { :type => 'agent_available', 
				:user => { :id => user.id, 
					:name => user.name,
					:avatar => user_avatar(user)
				}
			}
			add_to_set(key, user.id)
		else
			message = {:type => 'agent_unavailable', :user => {:id => user.id}}
			remove_value_from_set(key, user.id)
		end
		publish_to_channel(channel, message.to_json)
	end

  private
    def get_current_calls
      key = NEW_CALL % {:account_id => current_account.id}
      set_members key
    end
		
		def called_entity
			params[:direct_dial_number] || (current_user || {})[:id] || params[:agent]
		end
end