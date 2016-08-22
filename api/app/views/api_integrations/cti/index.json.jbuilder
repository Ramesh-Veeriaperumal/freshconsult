json.array! @items do |call|
  json.extract! call, :requester_id, :responder_id, :ticket_id, :note_id
end
