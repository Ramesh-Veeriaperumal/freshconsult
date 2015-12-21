class Solution::BinarizeObserver < ActiveRecord::Observer

	observe Solution::Article, Solution::Folder, Solution::Category

	def after_create(object)
		return unless multilingual
		meta(object)
		update_available(object, true)
		update_published(object)
		update_outdated(object)
		save_meta(object)
	end

	def after_update(object)
		return unless multilingual
		meta(object)
		update_published(object)
		update_outdated(object)
		save_meta(object)
	end

	def after_destroy(object)
		return unless multilingual
		meta(object)
		update_available(object, false)
		save_meta(object)
	end

	private

		def multilingual
			Account.current.multilingual?
		end

		def meta(object)
			@meta = object.parent
			@parent_changes = @meta.changes.present?
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
			@meta.send("#{val ? :mark : :unmark}_#{language_key}_#{key}") if @meta.respond_to?(key)
		end

		def save_meta(object)
			if object.is_a? Solution::Article
				return if @parent_changes
				return if (object.draft.present? && object.draft.new_record?)
			end
			@meta.save
		end
end