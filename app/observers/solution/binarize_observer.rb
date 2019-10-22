class Solution::BinarizeObserver < ActiveRecord::Observer

	observe Solution::Article, Solution::Folder, Solution::Category

	def after_commit(object)
		return unless multilingual
		meta(object)
		return unless @meta
		if object.safe_send(:transaction_include_action?, :destroy)
			update_available(object, false)
		else
			update_available(object, true)
			update_published(object)
			update_outdated(object)
		end
		save_meta(object)
	end

	private

		def multilingual
			Account.current.multilingual_available?
		end

		def meta(object)
			@meta = "#{object.class.name}Meta".constantize.find_by_id(object.parent_id)
			#To avoid AR Not Found errors on a MetaObject destroy.
		end

		def update_available(object, status)
			update_key(:available, object.language_key, status)
		end

		def update_published(object)
			return unless object.respond_to?(:status)
			update_key(:published, object.language_key, object.published?)
		end

		def update_outdated(object)
			return unless object.respond_to?(:outdated)
			update_key(:outdated, object.language_key, object.outdated)
		end

		def update_key(key, language_key, val)
			@meta.safe_send("#{language_key}_#{key}=", val) if @meta.respond_to?(key)
		end

		def save_meta(object)
			@meta.save
		end
end
