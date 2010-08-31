atom_feed do |feed|
  feed.title(h current_selector_name)
  feed.updated(@items.first.created_at)

  @items.each do |item|
    feed.entry(item) do |entry|
      entry.author do |author|
        author.name(h item.user.name)
      end
      entry.title(h item.title)


      description = simple_format(item.description) 

      notes = content_tag(:ul, item.notes.newest_first.map { |n| 
          content_tag(:li, "<cite>Note By #{n.user ? n.user.name : "Anonymous"} on #{n.created_at}</cite>" + simple_format(n.body)) 
      })

      entry.content(description + notes, :type => 'html')

    end
  end
end
