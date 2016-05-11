module UrlValidator
	def validate_permissible_domain
    url = UriParser.new(self.domain).valid_hosts
    if url[:errors]
      self.errors.add(:base, url[:errors])
    else
      self.domain = url[:hosts].first
    end
  end
end