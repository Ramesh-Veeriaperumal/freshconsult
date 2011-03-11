atom_feed do |feed|
  feed.title(@forum.name)
  @topics.each do |item|
    feed.entry(item,:url => category_forum_topic_url(@forum_category.id,@forum.id,item.id)) do |entry|
      entry.title(h item.title)
      entry.count(item.posts.count)
      entry.body(item.posts.first.body)
    end
  end
end