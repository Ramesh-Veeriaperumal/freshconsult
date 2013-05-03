// Slidebar menu with animation 
(function( $ ){
  $.fn.slide = function(options) {
    var settings = $.extend({ width:false, direction:'left', duration:"faster" }, options);

    return this.each(function() {
		$this = $(this)
		$slider = $($this.attr("href"))
		$parent = $($this.data("parent"))
		$slider.css({'visibility':'hidden', 'display':'block'})//display:none have to be clear for calculate correct width
		$parent.show() 

		var el = get_common_ancestor($slider, $parent)
		var parent_width = $parent.outerWidth(true)
		var parent_height = Math.max($parent.outerHeight(true), $slider.outerHeight(true))
		var org_width = (!settings.width) ? $slider.outerWidth(true) : settings.width

		$(el).css({'position':'relative', 'overflow':'hidden', 'padding':'0'}).data("sliderOpen", true)
		$slider.css({'left':"-"+org_width+"px", 'position':'absolute'})
		$parent.css({
			'left':"0", 
			'position':'relative', 
			'width': org_width+parent_width, 
			'min-height': parent_height,
			'height':'auto !important', 
   			'height': parent_height
		})

		$this.live("click", function(ev){
			ev.preventDefault()
			toggle_slide()
		});

      	$slider.delegate("[data-dismiss=slider]", "click", function(ev) {
	        ev.preventDefault()	        
	        toggle_slide(false)
	    });

      	$slider.change(function(){
      		if($slider.height() > $parent.height()){
      			$parent.height($slider.height())
      		}
      	})

	    function toggle_slide(slide_open){
	    	slide_open = slide_open || $(el).data("sliderOpen")

	      	if(slide_open){
		      	$(el).addClass('slide-shadow', { duration: settings['duration'], "easing": "easeOutExpo"})
		      	$slider.css({'visibility':'visible'})
		        $slider.animate({ 'left':"0" }, { duration: settings['duration'], "easing": "easeOutExpo"})
		        $parent.animate({"left":org_width+"px" }, { duration: settings['duration'] , "easing": "easeOutExpo"})
		        $(el).data("sliderOpen", false)
		    }else{
		    	$slider.animate({
			        "left":"-"+org_width+"px"
			        }, { duration: settings['duration'] , "easing": "easeOutExpo"})
		    	$slider.css({'visibility':'hidden'})
		        $parent.animate({
			        "left":"0"
			        }, { duration: settings['duration'] , "easing": "easeOutExpo"})
		        $(el).removeClass('slide-shadow', { duration: settings['duration'], "easing": "easeOutExpo"})
		        $(el).data("sliderOpen", true)
		    }
      	}
    })
  }
})( jQuery );

function get_common_ancestor(a, b)
{
    $parentsa = $(a).parents();
    $parentsb = $(b).parents();
    var found = null;
    $parentsa.each(function() {
        var thisa = this;
        $parentsb.each(function() {
            if (thisa == this)
            {
                found = this;
                return false;
            }
        });
        if (found) return false;
    });
    return found;
}