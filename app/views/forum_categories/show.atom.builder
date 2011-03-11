atom_feed do |feed|
  feed.title(@forum_category.name)
  @forums.each do |item|
    feed.entry(item,:url => category_forum_url(@forum_category.id,item.id)) do |entry|
      entry.title(h item.name)
      entry.content(simple_format(item.description), :type => 'html')
    end
  end
end