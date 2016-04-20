Dir['test/api/functional/api_discussions/*_test.rb'].each { |file| require "./#{file}" }

#Unit
require_relative '../unit/api_comment_validation_test.rb'
require_relative '../unit/api_comments_dependency_test.rb'
require_relative '../unit/category_validation_test.rb'
require_relative '../unit/categories_dependency_test.rb'
require_relative '../unit/forum_validation_test.rb'
require_relative '../unit/forums_dependency_test.rb'
require_relative '../unit/topic_validation_test.rb'
require_relative '../unit/topics_dependency_test.rb'
require_relative '../unit/monitor_validation_test.rb'

#Flows
require_relative '../integration/flows/api_discussions_flow_test.rb'

#Queries
# require_relative 'integration/queries/api_comments_queries_test.rb'
# require_relative 'integration/queries/categories_queries_test.rb'
# require_relative 'integration/queries/forums_queries_test.rb'
# require_relative 'integration/queries/topics_queries_test.rb'