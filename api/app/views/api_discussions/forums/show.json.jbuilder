json.partial! 'api_discussions/forums/forum', f: @forum
json.set! :topics do
  json.array! @topics, partial: 'api_discussions/topics/topic', as: :t
end  