class Solution::BinarizeObserver < ActiveRecord::Observer
    
  observe Solution::Article, Solution::Folder, Solution::Category

  def after_create(object)
  	meta(object)
  	update_available(object, true)
  	if object.class.name.eql?("Solution::Article")
	  	update_published(object)
	  	update_outdated(object)
	  end
	  save_meta
  end

  def after_update(object)
  	return unless object.class.name.eql?("Solution::Article")
    return unless object.status_changed? or object.outdated_changed?
    meta(object)
  	update_published(object)
  	update_outdated(object)
    save_meta
  end

  def after_destroy(object)
  	meta(object)
  	update_available(object, false)
  	save_meta
  end

  private

  	def meta(object)
  		@meta = object.send("#{object.class.name.underscore.gsub('/', '_')}_meta")
  	end

  	def update_available(object, status)
  		update_key(:available, object.language_key, status)
  	end

		def update_published(object)
			update_key(:published, object.language_key, object.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published])
		end

		def update_outdated(object)
			update_key(:outdated, object.language_key, object.outdated)
		end

		def update_key(key, language_key, val)
	  	@meta.send("#{language_key}_#{key}=", val)
		end

		def save_meta
			@meta.save
		end
end