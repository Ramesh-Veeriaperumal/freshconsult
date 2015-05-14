json.partial! 'api_discussions/topics/topic', t: @topic
json.set! :posts do
  json.partial! 'api_discussions/posts/post_list'
end  