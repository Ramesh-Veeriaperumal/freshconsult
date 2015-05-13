json.partial! 'api_discussions/categories/forum_category', fc: @category
json.set! :forums do
  json.array! @forums, partial: 'api_discussions/forums/forum', as: :f
end  