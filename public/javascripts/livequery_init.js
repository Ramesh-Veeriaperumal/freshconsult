(function($){
'use strict';

$(document).ready(function() {
//Added for social tweet links
$(".autolink").livequery(function(ev){
  $(this).autoLink();
})

$('.menuselector').livequery(
	function(){
		$(this).menuSelector()
	},function(){
		$(this).menuSelector('destroy')
	}
);
$('.tooltip').livequery(
	function(){
		$(this).twipsy();
	}
);
$(".full-width-tooltip").livequery(
	function(){
		$(this).twipsy({
			template: '<div class="twipsy-arrow"></div><div class="twipsy-inner big"></div>'
		});
	}
);
$(".form-tooltip").livequery(
	function(){
		$(this).twipsy({
		     	trigger: 'focus',
        			template: '<div class="twipsy-arrow"></div><div class="twipsy-inner big"></div>'
		    });
	}
);

$("a[rel=click-popover-below-left]").livequery(
	function(){
      $(this).popover({
        delayOut: 300,
        trigger: 'manual',
        offset: 5,
        html: true,
        reloadContent: false,
        placement: 'belowLeft',
        template: '<div class="dbl_up arrow"></div><div class="hover_card inner"><div class="content ' + $("#" + $(this).attr("data-widget-container")).data('container-class') + '"><div></div></div></div>',
        content: function(){
          return $("#" + $(this).attr("data-widget-container")).html();
        }
      });
    },
    function(){
    	$(this).popover('destroy')
    }
);

$("[rel=more-agents-hover]").livequery(
	function(){
		if(typeof agentCollisionData != 'undefined')
		{
			$(this).popover({
				delayOut: 300,
				trigger: 'manual',
				offset: 5,
				html: true,
				reloadContent: false,
				template: '<div class="dbl_left arrow"></div><div class="hover_card hover-card-agent inner"><div class="content"><div></div></div></div>',
				content: function(){
					var container_id = "agent-info-div";
					var agentContent = '<ul id='+container_id+' class="fc-agent-info">';
					var chatIcon ='';
					var chatIconClose = '';

					if(typeof window.freshchat != 'undefined' && freshchat.chatIcon){
						chatIcon ='<span class="active"><i class="ficon-message"></i></span> <a href="javascript:void(0)" class="tooltip"  title="Begin chat" data-placement="right">';
						chatIconClose = '</a>';
					}
					agentCollisionData.forEach(function(data){
						agentContent += '<li class ="agent_name" id="'+data.userId+'"> <strong>'+chatIcon +''+data.name +chatIconClose+'</strong></li>';
					});

					return agentContent+'</ul>';
				}
			});
		}
	},
	function(){
		$(this).popover('destroy');
	}
);

$("[rel=contact-hover]").livequery(
	function(){
		$(this).popover({
			delayOut: 300,
			trigger: 'manual',
			offset: 5,
			html: true,
			reloadContent: false,
			template: '<div class="dbl_left arrow"></div><div class="hover_card inner"><div class="content"><div></div></div></div>',
			content: function(){
				var container_id = "user-info-div-"+$(this).data('contactId');
				return jQuery("#"+container_id).html() || "<div class='sloading loading-small loading-block' id='"+container_id+"' rel='remote-load' data-url='"+$(this).data('contactUrl')+"'></div>";
			}
		});
	},
	function(){
		$(this).popover('destroy');
	}
);


$("a[rel=hover-popover-below-left]").livequery(
	function(){
		$(this).popover({
			delayOut: 300,
			offset: 5,
			trigger: 'manual',
			html: true,
			reloadContent: false,
			placement: 'belowLeft',
			template: '<div class="dbl_up arrow"></div><div class="hover_card inner"><div class="content ' + $("#" + $(this).attr("data-widget-container")).data('container-class') + '"><p></p></div></div>',
			content: function(){
				return $("#" + $(this).attr("data-widget-container")).val();
			}
		});
	},
	function(){
		$(this).popover('destroy');
	}
);

$("[rel=hover-popover]").livequery(
	function(){
		$(this).popover({
			delayOut: 300,
			trigger: 'manual',
			offset: 5,
			html: true,
			reloadContent: false,
			template: '<div class="dbl_left arrow"></div><div class="hover_card inner"><div class="content"><div></div></div></div>',
			content: function(){
				return $(this).data("content") || $("#" + $(this).attr("data-widget-container")).val();
			}
		});
	},
	function(){
		$(this).popover('destroy');
	}
);

$("textarea.autosize").livequery(
	function(){
		$(this).autosize();
	}
);

$("[rel=remote-load]").livequery(
	function(){
		if(!document.getElementById('remote_loaded_dom_elements'))
		$("<div id='remote_loaded_dom_elements' class='hide' />").appendTo("body");

		var $this = jQuery(this)

		$.ajax({
			type: 'GET',
			url: $(this).data("url"), 
			dataType: 'html',
			success: function(html){
				$this.html(html);
				$this.attr("rel", "");
				$this.removeClass("sloading loading-small loading-block");

				if(!$this.data("loadUnique"))
				$this.clone().prependTo('#remote_loaded_dom_elements');

				if($this.data("extraLoadingClasses"))
				$this.removeClass($this.data("extraLoadingClasses"));
			}
		});
	}
);

// Uses the date format specified in the data attribute [date-format], else the default one 'yy-mm-dd'
$("input.datepicker_popover").livequery(
	function() {
		var dateFormat = 'yy-mm-dd';
		if($(this).data('date-format')) {
			dateFormat = $(this).data('date-format');
		}

// Cloning date element to process in ISO format
	var clone_date = jQuery(this).clone().removeAttr('class data-date-format');
	var idForCloneElement = jQuery(this).prop("id");

  	clone_date.attr('id', 'clone_'+idForCloneElement).appendTo(this);
  	jQuery(this).removeAttr('name');
  	if((jQuery(this).val())==""){
  		jQuery('#'+idForCloneElement).attr('data-initial-val', 'empty');
  	}
  	else{
  		jQuery('#'+idForCloneElement).attr('data-initial-val', (jQuery(this).val()));
  	}
  	jQuery('#clone_'+idForCloneElement).hide();




jQuery.validator.addClassRules("date", {
				date: false
				});	

		
		$(this).datepicker({
			dateFormat: dateFormat,
			changeMonth: true,
            changeYear: true,
            altField: '#clone_'+idForCloneElement,
    		altFormat: 'yy-mm-dd',
			beforeShow: function(){
				Helpdesk.calenderSettings.insideCalendar = true;
				Helpdesk.calenderSettings.closeCalendar = false;
			},
			onClose: function(){
				Helpdesk.calenderSettings.closeCalendar = true;
			},
			showOn: "both",
			buttonText: "<i class='ficon-date'></i>",			
		});

// var varNewValue = (location.pathname).slice(-3); 
// varNewValue checks if last three char url is 'new' refering the new method
// if(!(varNewValue==="new")&&()){
// 	var getDateVal = (jQuery('#'+'clone_'+idForCloneElement).val());
//   	var DateVal = new Date(getDateVal);
//   	jQuery('#'+idForCloneElement).datepicker('setDate', DateVal);
// }


if((jQuery('#'+idForCloneElement).data('initial-val'))!="empty")
{
	var getDateVal = (jQuery('#'+'clone_'+idForCloneElement).val());
  	var DateVal = new Date(getDateVal);
  	jQuery('#'+idForCloneElement).datepicker('setDate', DateVal);
}




	//already included above
		// if($(this).data('showImage')) {	
		// 	$(this).datepicker('option', 'showOn', "both" );
		// 	$(this).datepicker('option', 'buttonText', "<i class='ficon-date'></i>" );
		// }

		// custom clear button
		var clearButton =  jQuery(this).siblings('.dateClear');
		if(clearButton.length === 0) {
			 clearButton = jQuery('<span class="dateClear"><i class="ficon-cross" ></i></div>');
			jQuery(this).after(clearButton);
		}
		if(jQuery(this).val().length === 0) {
			clearButton.hide();
		}
		jQuery(this).on("change",function(){
			if(jQuery(this).val().length === 0) {
				clearButton.hide();
			}
			else {
				clearButton.show();
			}

		});
		clearButton.on('click', function(e) {
			 jQuery(this).siblings('input.date').val("");
			 jQuery(this).hide(); 
			 jQuery('#'+'clone_'+idForCloneElement).val("");
		 });
		// clear button ends
	}
);



$('input.datetimepicker_popover').livequery(
	function() {
		$(this).datetimepicker({
			timeFormat: "HH:mm:ss",
			dateFormat: 'MM dd,yy',
			 changeMonth: true,
             changeYear: true,
			beforeShow: function(){
				Helpdesk.calenderSettings.insideCalenda = true;
				Helpdesk.calenderSettings.closeCalendar = false;
			},
			onClose: function(){
				Helpdesk.calenderSettings.closeCalendar = true;
			}
		});
	}
);

$("[rel=mouse-wheel]").livequery(
	function(){
		$(this).on('mousewheel DOMMouseScroll', function (ev) {
			if (ev.originalEvent) { ev = ev.originalEvent; }
			var delta = ev.wheelDelta || -ev.detail;
			this.scrollTop += (delta < 0 ? 1 : -1) * parseInt($(this).data("scrollSpeed"));
			ev.preventDefault();
		});
	}
);

// - Labels with overlabel will act a Placeholder for form elements
$("label.overlabel").livequery(function(){ $(this).overlabel(); });
$(".nav-trigger").livequery(function(){ $(this).showAsMenu(); });
$("input[rel=toggle]").livequery(function(){ $(this).itoggle(); });

$("select.select2").livequery(
	function(){
		var defaults = {
			minimumResultsForSearch:    10
		}
		$(this).select2($.extend( defaults, $(this).data()));
	},
	function(){
		$(this).select2('destroy');
	}
);

$("input.select2").livequery(
	function(){
		var defaults = {tags: [],tokenSeparators: [","],
			formatNoMatches: function () {
			return "  ";
			}
		}
		
		$(this).select2($.extend( defaults, $(this).data()));
	},
	function(){
		$(this).select2('destroy');
	}
);

// - Quote Text in the document as they are being loaded
$("div.request_mail").livequery(function(){ quote_text(this); });

$("input.datepicker").livequery(
	function(){
		$(this).datepicker(
			$.extend( {}, $(this).data() , { dateFormat: getDateFormat('datepicker'),changeMonth: true,changeYear: true }  )
			)
	}
);

$('.contact_tickets .detailed_view .quick-action').removeClass('dynamic-menu quick-action').attr('title','');

$('.quick-action.ajax-menu').livequery(function() { $(this).showAsDynamicMenu();});
$('.quick-action.dynamic-menu').livequery(function() { $(this).showAsDynamicMenu();});

// - Tour My App 'Next' button change
$(".tourmyapp-toolbar .tourmyapp-next_button").livequery(function(){
	if($(this).text() == "Next »")
	$(this).addClass('next_button_arrow').text('Next');
});

var layzr;
$(".image-lazy-load img").livequery(
	function(){
		layzr = new Layzr({
			container: null,
			selector: '.image-lazy-load img',
			attr: 'data-src',
			retinaAttr: 'data-src-retina',
			hiddenAttr: 'data-layzr-hidden',
			threshold: 0,
			callback: function(){
				$(".image-lazy-load img").css('opacity' , 1);
			}
		});
	},
	function() {
		layzr._destroy()
	}
);

$("ul.ui-form, .cnt").livequery(function(ev){
	$(this).not(".dont-validate").parents('form:first').validate();
})

$("div.ui-form").livequery(function(ev){
	$(this).not(".dont-validate").find('form:first').validate();
})

// $("form.uniForm").validate(validateOptions);
$("form.ui-form").livequery(function(ev){
	$(this).not(".dont-validate").validate();
})


// $("form[rel=validate]").validate(validateOptions);
var validateOptions = {}
validateOptions['submitHandler'] = function(form, btn) {
	// Setting the submit button to a loading state
	$(btn).button("loading")

	// IF the form has an attribute called data-remote then it will be submitted via ajax
	if($(form).data("remote")){
		$(form).ajaxSubmit({
			dataType: 'script',
			success: function(response, status){
			  // Resetting the submit button to its default state
			$(btn).button("reset");

			// If the form has an attribute called update it will used to update the response obtained
			  $("#"+$(form).data("update")).html(response)
			}
		})
	// For all other form it will be a direct page submission
	}else{
		setTimeout(function(){
			add_csrf_token(form);
			// Nullifies the form data changes flag, which is checked to prompt the user before leaving the page.
			$(form).data('formChanged', false);
			form.submit();
		}, 50)
	}
}
// Form validation any form append to the dom will be tested via live query and then be validated via jquery
$("form[rel=validate]").livequery(function(ev){
	$(this).validate($.extend( validateOptions, $(this).data()))
})

$('#Activity .activity > a').livequery(function() {
	$(this).attr('data-pjax', '#body-container')
});


$('[rel="select-choice"]').livequery(
	function(ev) {
		var maxSelectionsize = $(this).data('maxSelectionSize') || 10;
		jQuery(this).select2({
														maximumSelectionSize: maxSelectionsize,
														removeOptionOnBackspace:false
												});

		var $select_content = $(this).siblings('.select2-container'),
			disableField = $(this).data('disableField');

		disableField = disableField.split(',');

		$select_content.find(".select2-search-choice div").each(function(index,element){
			var value = jQuery(element).text();

			if($.inArray(value, disableField ) != -1) {
				jQuery(element).next("a").remove();
			}
		});
	},
	function(){
		$(this).select2('destroy');
	}
)

$("[rel=sticky]").livequery(
	function(){
		var scroll_top = $(this).data('scrollTop');
		$(this).sticky();
		$(this).on("sticky_kit:stick", function(e){
			if(scroll_top){
				if(!$('#scroll-to-top').length){
					$(this).append("<i id='scroll-to-top'></i>")
				}
				$('#scroll-to-top').addClass('visible');
			}
		})
		.on("sticky_kit:unstick", function(e){
			if(scroll_top){$('#scroll-to-top').removeClass('visible');}
		});
	}
);

$('.btn-collapse').livequery(
	function(){
		$(this).collapseButton();
	}
);

	// Image enlarger - Ticket details
	$("[rel='image-enlarge'] img").livequery(function () {			
    var img = $(this);
  	$("<img/>")
    .attr("src", img.attr("src"))
    .on('load', function() {

      var originalWidth = this.width,
        originalHeight = this.height,
        outerWidth = $(img).actual('width'),  // outerWidth/outerHeight will be 0 for hidden element.So we are user jQuery.actual.min.js to get width/height
        outerHeight = $(img).actual('height'),
        originalAspectRatio = originalWidth / originalHeight,
        aspectRatio = outerWidth / outerHeight;

      if(aspectRatio !== originalAspectRatio) {
        img.outerHeight(outerWidth/originalAspectRatio);
        
        if(!img.parent('a').get(0)) {
			  	img.wrap(function(){
				    return "<a target='_blank' class='image-enlarge-link' href='" + this.src + "'/>";
				  });
			  }
      }

    });
	});

	// Remote tags
	// default value should be given in VALUE attribute
	// 
	$('[rel=remote-tag]').livequery(function() {
		var hash_val = []
		var _this = $(this);
		_this.val().split(",").each(function(item, i){ hash_val.push({ id: item, text: item }); });
		_this.select2({
			multiple: true,
			maximumInputLength: 32,
			data: hash_val,
			quietMillis: 500,
			ajax: { 
        url: '/search/autocomplete/tags',
        dataType: 'json',
        data: function (term) {
            return { q: term };
        },
        results: function (data) {
          var results = [];
          jQuery.each(data.results, function(i, item){
          	var result = escapeHtml(item.value);
            results.push({ id: result, text: result });
          });
          return { results: results }
        }
			},
			initSelection : function (element, callback) {
			  callback(hash_val);
			},
		    formatInputTooLong: function () { 
      	return MAX_TAG_LENGTH_MSG; },
		  createSearchChoice:function(term, data) { 
		  	//Check if not already existing & then return
        if ($(data).filter(function() { return this.text.localeCompare(term)===0; }).length===0)
	        return { id: term, text: term };
		    }
				});
		}, function(){
			$(this).select2('destroy');
		});

});

})(jQuery);
