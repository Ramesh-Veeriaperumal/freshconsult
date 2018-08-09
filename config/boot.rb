require 'rubygems'

# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])

env = ENV['RAILS_ENV'] || "development"

# First cut, enable Bootsnap in dev alone and monitor.
# If no issues then include ENV['ENABLE_BOOTSNAP'] in ruby-with-env nginx config for staging/prod.

ENV['ENABLE_BOOTSNAP'] = "true" if env == 'development'

# if ENV['ENABLE_BOOTSNAP'] == "true"
#   require 'bootsnap'
#   Bootsnap.setup(
#     cache_dir:            'tmp/cache',
#     development_mode:     env == 'development',
#     load_path_cache:      true,  # Optimize the LOAD_PATH with a cache
#     autoload_paths_cache: false, # Optimize ActiveSupport autoloads with cache
#     disable_trace:        true,  # (Alpha) Set `RubyVM::InstructionSequence.compile_option = { trace_instruction: false }`
#     compile_cache_iseq:   false,  # Compile Ruby code into ISeq cache, breaks coverage reporting.
#     compile_cache_yaml:   false   # Compile YAML into a cache
#   )
# end
