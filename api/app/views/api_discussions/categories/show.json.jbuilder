json.partial! 'api_discussions/categories/forum_category', fc: @category
json.set! :forums do
  json.partial! 'api_discussions/forums/forum_list'
end  