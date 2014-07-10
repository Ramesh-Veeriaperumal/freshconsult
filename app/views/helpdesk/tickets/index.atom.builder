atom_feed do |feed|
  feed.title(h current_selector_name)
  feed.updated(@items.first.created_at)

  @items.each do |item|
    feed.entry(item) do |entry|
      entry.title(h item.name)
      entry.content(simple_format(item.description), :type => 'html')

      entry.author do |author|
        author.name(h item.name)
      end
    end
  end
end
