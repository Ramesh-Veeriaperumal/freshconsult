module CustomLiquid
	module Tags
		class Translate < ::Liquid::Tag
			def initialize(tag_name, key, tokens)
				super
				@translate_key = key
			end

			def render(context)
				#t(@translate_key).to_s
				"ABC"
			end
		end
	end
end