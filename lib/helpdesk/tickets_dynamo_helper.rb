module Helpdesk::TicketsDynamoHelper

  #Dynamo constants
  TABLE_NAME = "helpkit_ticket"
  HASH_KEY = "ticket_account"
  ASSOCIATES = "associates"

  def associates
      #get item
      hash =  {
         :key => HASH_KEY, 
         :value => "#{self.id}_#{self.account.id}"
        }
      resp = Helpdesk::Tickets::Dynamo::DynamoHelper.get_item(
                TABLE_NAME, 
                hash, 
                nil, 
                "#{HASH_KEY},
                #{ASSOCIATES}",
                true)
     return resp.data.item[ASSOCIATES].map {|e| e.to_i} if resp_item?(resp)
     nil
  end

  def associates=(val)
      #get item
      hash =  {
         :key => HASH_KEY, 
         :value => "#{self.id}_#{self.account.id}"
        }
      resp = Helpdesk::Tickets::Dynamo::DynamoHelper.put_item(
                TABLE_NAME, 
                hash, 
                nil, 
                {ASSOCIATES => val.to_set}) #dynamo needs the value to be in a set
     return resp.data.attributes[ASSOCIATES].map {|e| e.to_i} if resp_data?(resp)
     nil
  end

  def add_associates(val)
    update_associates(val,"ADD")
  end

  def remove_associates(val)
    update_associates(val,"DELETE")
  end

  def update_associates(val, action="ADD")
        hash =  {
         :key => HASH_KEY, 
         :value => "#{self.id}_#{self.account.id}"
        }
    resp = Helpdesk::Tickets::Dynamo::DynamoHelper.update_set_attributes(
                TABLE_NAME, 
                hash, nil,
                {ASSOCIATES => val}, action)
    return resp.data.attributes[ASSOCIATES].map {|e| e.to_i} if resp_data?(resp)
    nil
  end

  def resp_data?(resp)
    resp and resp.data and resp.data.attributes and resp.data.attributes[ASSOCIATES]
  end

  def resp_item?(resp)
    resp and resp.data and resp.data.item and resp.data.item[ASSOCIATES]
  end

end