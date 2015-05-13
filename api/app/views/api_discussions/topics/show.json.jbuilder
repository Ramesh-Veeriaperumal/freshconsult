json.partial! 'api_discussions/topics/topic', t: @topic
json.set! :posts do
  json.array! @posts, partial: 'api_discussions/posts/post', as: :p
end  