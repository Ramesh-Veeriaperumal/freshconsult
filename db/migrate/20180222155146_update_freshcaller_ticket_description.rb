class UpdateFreshcallerTicketDescription < ActiveRecord::Migration
  shard :all
  def change
    ::Freshcaller::Account.find_in_batches(batch_size: 30) do |batch|
      ::Account.reset_current_account
      batch.each do |fc_account|
        ::Account.reset_current_account
        Sharding.select_shard_of fc_account.account_id do
          account = ::Account.find(fc_account.account_id)
          next if account.blank?
          account.make_current
          account.freshcaller_calls.where('notable_id IS NOT NULL').find_in_batches(batch_size: 100) do |call_batch|
            call_batch.each do |call|
              ticket = call.notable if call.notable_type.eql?('Helpdesk::Ticket')
              ticket = call.notable.try(:notable) if call.notable_type.eql?('Helpdesk::Note')
              next if ticket.blank? || (ticket.source_name != 'Phone') || ticket.description.present?
              ticket.ticket_body_attributes = { description: ticket.description_html, description_html: ticket.description_html}
              ticket.save_ticket
            end
          end
        end
      end
    end
  end
end
