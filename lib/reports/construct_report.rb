module Reports::ConstructReport
  
  def tkts_by_status(tkts,info)
   data = {}
   tkts.each do |tkt|
    status_hash = {}
    info_val = info.eql?("responder") ? "email" : "name"
    responder = tkt.send("#{info}").blank? ? "Unassigned" : tkt.send("#{info}").send("#{info_val}")
    if data.has_key?(responder)
      status_hash = data.fetch(responder)
    end
    status_hash.store(TicketConstants::STATUS_NAMES_BY_KEY[tkt.status],tkt.count)
    tot_count = status_hash.fetch(:tot_tkts,0) + tkt.count.to_i
    status_hash.store(:tot_tkts,tot_count)
    data.store(responder,status_hash)
   end
     data
  end
end