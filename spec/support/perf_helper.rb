require 'spec_helper'

#http://signalvnoise.com/posts/2742-the-road-to-faster-tests
module PerfHelper

	DEFERRED_GC_THRESHOLD = (ENV['DEFER_GC'] || 2.0).to_f

	@@last_gc_run = Time.now

	def begin_gc_defragment
	  GC.disable if DEFERRED_GC_THRESHOLD > 0
	end

	def reconsider_gc_defragment
	  if DEFERRED_GC_THRESHOLD > 0 && Time.now - @@last_gc_run >= DEFERRED_GC_THRESHOLD
	    GC.enable
	    GC.start
	    GC.disable

	    @@last_gc_run = Time.now
	  end
	end	
end