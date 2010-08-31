atom_feed do |feed|
  feed.title(h @item.title)
  feed.updated(@item.notes.first.created_at)

  @item.notes.visible.newest_first.find_all_by_private(true).each do |note|
    feed.entry(note, :url => polymorphic_url(note.notable)) do |entry|

      entry.title(h "Note")
      entry.content(simple_format(note.body), :type => 'html')
      entry.author do |author|
        author.name(note.user ? note.user.name : 'staff')
      end
    end
  end
end
