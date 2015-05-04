class PopulateTransferByToFfCallsMeta < ActiveRecord::Migration
  shard :all

  def up
     Freshfone::Account.find_each do |freshfone_account|
      account = freshfone_account.account
      account.freshfone_calls.where('freshfone_calls.ancestry is not null').find_in_batches do |batch_of_calls|
        batch_of_calls.each do |call|
          call_meta = call.meta || Freshfone::CallMeta.find_or_initialize_by_account_id_and_call_id(account.id, call.id)
          call_meta.created_at = call.created_at
          call_meta.updated_at = call.updated_at
          call_meta.transfer_by_agent = transfered_by(call,account.freshfone_calls)
          call_meta.save! 
        end
      end
     end
  end

  def down
     Freshfone::Account.find_each do |freshfone_account|
      account = freshfone_account.account
      account.freshfone_calls.where('freshfone_calls.ancestry is not null').find_in_batches do |batch_of_calls|
        batch_of_calls.each do |call|
          call_meta = call.meta || Freshfone::CallMeta.find_or_initialize_by_account_id_and_call_id(account.id, call.id)
          call_meta.transfer_by_agent = nil
          call_meta.save!
        end

      end
     end
    # execute ("update freshfone_calls_meta set transfer_by_agent = null")
  end

  def transfered_by(call,all_calls)
    return call.parent.user_id if call.is_only_child?
    sibling_ids = call.sibling_ids.sort.reverse! # to order it from the current call id upwards
    transfering_call = all_calls.find(sibling_ids[1])
    transfering_call.user_id unless busy_or_missed?(transfering_call.call_status)#zero index is the current call id.
  end

  def busy_or_missed?(call_status)
    [ Freshfone::Call::CALL_STATUS_HASH[:busy], Freshfone::Call::CALL_STATUS_HASH[:missed] ].include?(call_status)
  end
end
