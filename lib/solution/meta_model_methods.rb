module Solution::MetaModelMethods

	def self.included(base)
		I18n.available_locales.map(&:to_s).map{|l| l.gsub('-','_')}.each do |language|
			base.class_eval do
				has_one "#{language}_language".to_sym, 
								:class_name => base.name[0..-5], 
								:foreign_key => :parent_id,
								:conditions => { 
									:language_id => Language.find_by_code(language.gsub('_','-')).id
								}
			end
		end
		base.class_eval do
			has_one "primary_language".to_sym, 
								:class_name => base.name[0..-5], 
								:foreign_key => :parent_id,
								:conditions => proc { "language_id = '#{Language.for_current_account.id}'" }
		end
	end

end