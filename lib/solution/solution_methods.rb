module Solution::SolutionMethods

  def encode_emoji_in_articles
    self.title = UnicodeSanitizer.remove_4byte_chars(self.title)
  end
end
