module Ecommerce::Ebay::ReplyHelper
  include Ecommerce::Ebay::Constants

  def ebay_reply
    build_attachments @item, :helpdesk_note
    if @item.save_note
      message = ebay_call
      @item.build_ebay_question(:user_id => current_user.id, :item_id => @parent.ebay_question.item_id, :ebay_account_id => @parent.ebay_question.ebay_account_id, :account_id => @parent.account_id)
      if message && @item.ebay_question.save
        Ecommerce::EbayMessageWorker.perform_async({:ebay_account_id => @parent.ebay_question.ebay_account_id ,:ticket_id => @parent.id, :note_id => @item.id, :start_time => message[:timestamp].to_time})
        flash[:notice] = t(:'flash.tickets.reply.success') 
        process_and_redirect
      else
        @item.deleted = true
        @item.save
        ebay_error("admin.ecommerce.ebay_note_not_added") 
      end
    else
      ebay_error('admin.ecommerce.ebay_error.note_not_added')
    end
  rescue Exception => e
    ebay_error("admin.ecommerce.ebay_error.note_not_added")
  end

  def validate_ecommerce_reply
    if @item.body.length > EBAY_REPLY_MSG_LENGTH
      ebay_error('admin.ecommerce.ebay_error.reply_length_exceed')
    elsif @parent.ebay_question.blank?
      ebay_error('admin.ecommerce.ebay_error.invalid_source')
    end
  end

  def ebay_call
    Ecommerce::Ebay::Api.new({:ebay_account_id => @parent.ebay_question.ebay_account_id}).make_ebay_api_call(:reply_to_buyer, :ticket => @parent, :note => @item)
  end

  def ebay_error(msg)
    flash[:notice] = t(msg)
    create_error
  end      
end