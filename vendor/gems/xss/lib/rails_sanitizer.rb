class RailsSanitizer
    extend ActionView::Helpers::SanitizeHelper::ClassMethods
end

class RailsFullSanitizer
	def self.sanitize(text)
		ActionController::Base.helpers.sanitize(RailsSanitizer.full_sanitizer.sanitize(text))
	end
end
