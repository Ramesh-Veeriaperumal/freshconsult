module EtagGenerator
  # Right now its simple. May be we can customize and generate later. Moved it as module for easy use.
  def self.generate_etag(value, current_version)
    "W/#{current_version}-#{value}"
  end
end
