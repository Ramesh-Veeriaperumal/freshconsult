(function($){

		$.fn.pickList = function(options){
			var defaults = {
				listId: $('[data-picklist]')
			}

			var obj = $.extend(defaults, options);
			return this.each(function () {
				 var $selectedObj = $(this);
				 destroyPicklist($selectedObj);
				 $selectedObj
				 .on('change.picklist', function(){
						var searchText = $(this).val().toLowerCase();
						if(jQuery("#filter-template").val().length > 0){
							jQuery('.recent').hide();
							jQuery('.seperator').hide();
						}else{
							jQuery('.recent').show();
							jQuery('.seperator').show();
						}
						obj.listId.children('li').each(function() {
								var string = $(this).text().toLowerCase();
								if(string.indexOf(searchText) != -1) {
									$(this).removeClass('hide');
								} else {
									$(this).addClass('hide');
								}
						});
				 })
				 .keydown(function(event){
					 if(!event.keyCode === 38 || !event.keyCode === 40){
						 		obj.listId.children('li').removeClass('active');
					 }
					if(event.keyCode == 38){
						event.preventDefault();
					}
					//  $(this).change();
				 })
				 handleEvents($selectedObj);
				 handleMouseEvents();
			 });

       function handleEvents(filterInput){
         $(filterInput).on('keydown.picklist keypress.picklist', function(event){
					 handleKeycode(event);
				 });
       }

			 function handleMouseEvents(){
				 var $list = $('[data-picklist] li');
				 $('[data-picklist]')
				 .on('mouseenter.picklist', 'li', function(event){
					 $list.removeClass('active');
					 var src = event.srcElement || event.target;
					 $(src).addClass('active');
				 });
			 }

			 function handleKeycode(event){
					 switch(event.keyCode){
						 case 38:
              switchActive(1);
						 break;
						 case 40:
              switchActive(-1);
						 break;
             case 13:
              handleEnter(event);
						 break;

						 default:
						 break;
					 }
			 }

       function switchActive(direction){
          var currActive = jQuery('[data-picklist]').children('li.active');
					if(currActive.length === 0){
						  jQuery('[data-picklist]').find('li').first().addClass('active');
					}
          if(direction === 1 && $(currActive).data('id') !== jQuery('[data-picklist]').children('li').first().data('id')){
            // Move up
						$(currActive).prevAll('.tkt-tmpl').first().addClass('active');
            $(currActive).removeClass('active');
						moveElement();
          }
          if(direction === -1 && $(currActive).data('id') !== jQuery('[data-picklist]').children('li').last().data('id')){
            // Move down
						$(currActive).nextAll('.tkt-tmpl').first().addClass('active');
            $(currActive).removeClass('active');
						moveElement();
          }

       }

			 function moveElement(){
				 var topElement = jQuery('[data-picklist] li.active') || jQuery('[data-picklist] li').first();
				 var topPosition = topElement.offset().top;
				 var index = jQuery('[data-picklist] li.active').index();
				 var height = jQuery('[data-picklist] li').innerHeight();
				 var recentHeight = jQuery('[data-picklist] .recent').innerHeight();
				 if(topPosition > 350 || topPosition < 200){
					 jQuery('[data-picklist]').scrollTop(index * height);
				 }
			 }

			 function destroyPicklist($selectedObj){
				 $selectedObj.off('.picklist');
			 }

       function handleEnter(e){
				 e.preventDefault();
				 obj.callback();
       }

		}
})(jQuery);
