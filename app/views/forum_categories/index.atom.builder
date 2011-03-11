 atom_feed do |feed|
  feed.title("Forum Categories")
  @forum_categories.each do |item|
    feed.entry(item,:url => category_url(item.id)) do |entry|
      entry.title(h item.name)
      entry.content(simple_format(item.description), :type => 'html')
    end
  end
end