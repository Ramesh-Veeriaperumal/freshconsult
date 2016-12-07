module Solution::PortalCacheMethods

  extend ActiveSupport::Concern

  included do |base|

    base::CACHE_METHODS.each do |meth|
      define_method("#{meth}_with_cache_fetch") do
        if User.current && Account.current.launched?(:portal_solution_cache_fetch) && additional_check_for_cache_fetch(meth)
          send("#{meth}_from_cache")
        else
          send("#{meth}_without_cache_fetch")
        end
      end

      base.alias_method_chain meth, :cache_fetch
    end
  end

  def additional_check_for_cache_fetch(meth)
    true
  end
end