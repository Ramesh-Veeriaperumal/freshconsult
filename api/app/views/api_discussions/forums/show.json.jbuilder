json.partial! 'api_discussions/forums/forum', f: @forum
json.set! :topics do
  json.partial! 'api_discussions/topics/topic_list'
end  