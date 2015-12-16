class Solution::BinarizeObserver < ActiveRecord::Observer

	observe Solution::Article, Solution::Folder, Solution::Category

	def after_create(object)
		meta(object)
		update_available(object, true)
		update_published(object)
		update_outdated(object)
		save_meta
	end

	def after_update(object)
		meta(object)
		toggle_keys(object) if object.language_id_changed?
		update_published(object)
		update_outdated(object)
		update_available(object, true)
		save_meta
	end

	def after_destroy(object)
		meta(object)
		update_available(object, false)
		save_meta
	end

	private

		def meta(object)
			@meta = object.parent
		end

		def update_available(object, status)
			update_key(:available, object.language_key, status)
		end

		def update_published(object)
			return unless object.respond_to?(:status)
			update_key(:published, object.language_key, object.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published])
		end

		def update_outdated(object)
			return unless object.respond_to?(:outdated)
			update_key(:outdated, object.language_key, object.outdated)
		end

		def toggle_keys(object)
			old_language_key = Language.find(object.language_id_was).to_key
			update_key(:available, old_language_key, false)
			update_key(:published, old_language_key, false)
			update_key(:outdated, old_language_key, false)
			update_draft_keys(object, old_language_key)
		end

		def update_draft_keys(object, old_language_key)
			return unless object.respond_to?(:draft) && object.draft.present?
			update_key(:draft, old_language_key, false)
			update_key(:draft, object.language_key, true)
		end

		def update_key(key, language_key, val)
			@meta.send("#{val ? :mark : :unmark}_#{language_key}_#{key}") if @meta.respond_to?(key)
		end

		def save_meta
			@meta.save
		end
end