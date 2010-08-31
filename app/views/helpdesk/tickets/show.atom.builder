atom_feed do |feed|
  feed.title(h @item.name)
  feed.updated(@item.notes.first.created_at)

  @item.notes.newest_first.each do |note|
    feed.entry(note, :url => polymorphic_url(note.notable)) do |entry|

      if note.incoming
        entry.title(h "Message received from #{@item.name}")
      elsif note.private
        entry.title(h "Note")
      else
        entry.title(h "Message sent by #{note.user ? note.user.name : 'staff'}")
      end
      
      entry.content(simple_format(note.body), :type => 'html')

      entry.author do |author|
        author.name(h(note.incoming ? @item.name : (note.user ? note.user.name : 'staff')))
      end
    end
  end
end
