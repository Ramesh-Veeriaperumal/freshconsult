module EtagGenerator
  # Right now its simple. May be we can customize and generate later. Moved it as module for easy use.
  def self.generate_etag(value)
    "W/#{value}"
  end
end
