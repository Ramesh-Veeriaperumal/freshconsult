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

		$(this).load($(this).data("url"), function(){
			$(this).attr("rel", "");
			$(this).removeClass("sloading loading-small loading-block");

			if(!$this.data("loadUnique"))
			$(this).clone().prependTo('#remote_loaded_dom_elements');

			if($this.data("extraLoadingClasses"))
			$(this).removeClass($this.data("extraLoadingClasses"));
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
		$(this).datepicker({
			dateFormat: dateFormat,
			 changeMonth: true,
             changeYear: true,
			beforeShow: function(){
				Helpdesk.calenderSettings.insideCalendar = true;
				Helpdesk.calenderSettings.closeCalendar = false;
			},
			onClose: function(){
				Helpdesk.calenderSettings.closeCalendar = true;
			}
		});
		if($(this).data('showImage')) {
			$(this).datepicker('option', 'showOn', "both" );
			$(this).datepicker('option', 'buttonText', "<i class='ficon-date'></i>" );
		}
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
		$(this).select2({tags: [],tokenSeparators: [","],
			formatNoMatches: function () {
			return "  ";
			}
		});
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
		jQuery(this).select2({maximumSelectionSize: 10,removeOptionOnBackspace:false});

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

});

})(jQuery);