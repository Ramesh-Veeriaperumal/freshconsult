jQuery(function($){
  $("[rel=ordered_dropdown] select").live("change", function(event){
    if(event.added) {
      var $element = $(event.added.element);
      $element.appendTo($element.parent());
    }
  });
});

function showItemsInOrder(category_ids, id) {
  jQuery.each(category_ids, function() {
    var $selection = jQuery("#"+id+"[rel=ordered_dropdown]");
    var $cat_option = $selection.find("select option[value="+this+"]");
    $cat_option.appendTo($selection.find("select"));
    $selection.find("ul li").each(function(){
      if(jQuery(this).find("div").html() == $cat_option.html()){
        jQuery(this).insertBefore($selection.find("ul li:last"));
      }
    });
  })
}
