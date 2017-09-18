module EtagGenerator
  # Right now its simple. May be we can customize and generate later. Moved it as module for easy use.
  def self.generate_etag(value, current_version)
    "#{current_version}-W/#{value}"
  end
end
