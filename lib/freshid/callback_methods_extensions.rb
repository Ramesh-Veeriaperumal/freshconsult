module Freshid::CallbackMethodsExtensions
  def reset_tokens! user
    ###### Overridden ######
    user.reset_tokens!
  end
  
  def user_active? user
    ###### Overridden ######
    user.active_and_verified?
  end
  
  def company_field_update_required?
    ###### Overridden ######
    false
  end

  def fetch_user_by_uuid account, uuid
     ###### Overridden ######
     account.all_technicians.find_by_freshid_uuid(uuid)
  end

  def process_events_later(args)
    ###### Overridden ######
    Freshid::ProcessEvents.perform_async args
  end

end
