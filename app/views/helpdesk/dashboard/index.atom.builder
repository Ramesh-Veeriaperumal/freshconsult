atom_feed do |feed|
  feed.title("Helpdesk Dashboard")
  feed.updated(@items.first.created_at)

  @items.each do |note|
    feed.entry(note, :url => polymorphic_url(note.notable)) do |entry|

      if note.status?
        entry.title(h "Status Change")
      elsif note.incoming
        entry.title(h "Message received from #{note.notable.name}") 
      elsif note.private
        entry.title(h "Note on Ticket: #{note.notable.name}") if note.notable.is_a? Helpdesk::Ticket
        entry.title(h "Note on Issue: #{note.notable.title}") if note.notable.is_a? Helpdesk::Issue
      else
        entry.title(h "Message sent by #{note.user ? note.user.name : 'staff'}")
      end
      
      entry.content(simple_format(note.body), :type => 'html')

      entry.author do |author|
        author.name(h(note.incoming ? note.notable.name : (note.user ? note.user.name : 'staff')))
      end
    end
  end
end
