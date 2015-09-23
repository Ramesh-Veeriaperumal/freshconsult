module Ecommerce::Ebay::Notifications

  def ebay_get_item_transactions_response(args)
    Ecommerce::EbayUserWorker.perform_async({:account_id => args["account_id"] ,:body => args["body"]["GetItemTransactionsResponse"]}) 
  end

  def ebay_get_my_messages_response(args)
    Ecommerce::EbayWorker.perform_async({:account_id => args["account_id"] ,:body => args["body"]["GetMyMessagesResponse"]}) 
  end

end