module Cache
  module FragmentCache
    module Base

      include Cache::FragmentCache::Keys
      include Redis::OthersRedis
      include Redis::RedisKeys

      ITEM_DETAILS = [
        [:ticket_list_filters, TICKETS_LIST_PAGE_FILTERS, AGENT_LANGUAGE_LIST],
        [:agent_new_ticket, AGENT_NEW_TICKET_FORM, AGENT_LANGUAGE_LIST],
        [:compose_email_form, COMPOSE_EMAIL_FORM, AGENT_LANGUAGE_LIST],
        [:support_new_ticket, SUPPORT_NEW_TICKET_FORM, CUSTOMER_LANGUAGE_LIST]
      ]

      CACHED_ITEMS                  = ITEM_DETAILS.map {|i| i[0] }
      ITEM_TO_CACHE_KEY_MAPPING     = Hash[*ITEM_DETAILS.map {|i| [i[0], i[1]]}.flatten]
      FRAGMENT_TO_LANG_MAPPING      = Hash[*ITEM_DETAILS.map { |i| [i[0], i[2]] }.flatten]

      def enable_fragment_cache(cached_item, skip = false, &block)
        raise Exception unless CACHED_ITEMS.include?(cached_item)
        # Need not cache if User.current is nil -> Support new ticket => without logged in
        if !skip && User.current && (cached_item == :support_new_ticket && Account.current.launched?(:support_new_ticket_cache))
          cache(language_specific_cache_key(cached_item), &block)
        else
          block.call
        end
      # Rescue Dalli::RingError if memcache is down and make the call to DB directly.
      rescue Dalli::RingError
        block.call
      end
      
      def clear_fragment_caches(items = CACHED_ITEMS)
        # clearing all fragments, via ticket_field update or product CRUD or attachement integration CRUD, with no param passed
        # clearing specified fragments, via product controller
        lang_list_hash = {}
        (items & CACHED_ITEMS).each do |item|
          redis_key = FRAGMENT_TO_LANG_MAPPING[item] % {:account_id => Account.current.id }
          # query redis if not present in lang_list_hash
          lang_list_hash[redis_key] = language_list(redis_key) unless lang_list_hash[redis_key].present?
          clear_language_cache(ITEM_TO_CACHE_KEY_MAPPING[item], lang_list_hash[redis_key]) if lang_list_hash[redis_key].present?
        end
        # Clear the language specific redis key 
        lang_list_hash.keys.each do |key|
          clear_language_list(key)
        end
      end

      private
        
        def language_specific_cache_key(cached_item)
          case cached_item
          when :ticket_list_filters, :agent_new_ticket, :compose_email_form, :support_new_ticket
            redis_key = FRAGMENT_TO_LANG_MAPPING[cached_item] % {:account_id => Account.current.id }
            language_specific_fragment_process(redis_key, ITEM_TO_CACHE_KEY_MAPPING[cached_item])
          end
        end

        ##################  CODE REALTED TO FRAGMENT CACHING #################     

        def language_specific_fragment_process(lang_key, cache_key)
          lang = "#{I18n.locale}"
          add_language_list(lang_key, lang)
          fragment_cache_key_with_language(cache_key, lang)
        end

        def clear_language_cache(cache_key, lang_list)
          lang_list.each do |lang|
            frag_key = fragment_cache_key_with_language(cache_key, lang)
            ActionController::Base.cache_store.delete("views/#{frag_key}")
          end
        end
        
        def fragment_cache_key_with_language(key, language = I18n.locale)
          key % {:account_id => Account.current.id, :language => "#{language}"}
        end

        ################# CODE RELATED TO REDIS OPERATIONS ##############

        def add_language_list(lang_key, lang)
          add_member_to_redis_set(lang_key, lang)
        end

        def language_list(lang_key)
          get_all_members_in_a_redis_set(lang_key)
        end

        def clear_language_list(lang_key)
          remove_others_redis_key(lang_key)
        end

    end
  end
end
