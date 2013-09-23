define([
  'vendor/datepicker',
  'text!templates/search/daterange.html'
], function(datepicker,daterangeTemplate){  
      var $ = jQuery;
	var daterangeView = Backbone.View.extend({
		render:function(){			
			var daterange = $('<div>');
				daterange.attr('id','date-range');
				$('#date').append(daterange.html(_.template(daterangeTemplate,{"daterange":daterange})));
				this.picker();
     },

		picker:function(){
			var to = new Date();
			var from = new Date(to.getTime() - 1000 * 60 * 60 * 24 * 14);

			$('#datepicker-calendar').DatePicker({
			  inline: true,
			  date: [from, to],
			  calendars: 3,
			  mode: 'range',
			  current: new Date(to.getFullYear(), to.getMonth() - 1, 1),
			  onChange: function(dates,el) {
			    $('#date-range-field span').text(
			      dates[0].getDate()+' '+dates[0].getMonthName(false)+' '+
			      dates[0].getFullYear()+' - '+
			      dates[1].getDate()+' '+dates[1].getMonthName(false)+' '+
			      dates[1].getFullYear());
			  }
			});

			$('#date-range-field span').text(from.getDate()+' '+from.getMonthName(false)+' '+from.getFullYear()+' - '+
                                        to.getDate()+' '+to.getMonthName(false)+' '+to.getFullYear());
        
        	$('#date-range-field').bind('click', function(){
          		$('#datepicker-calendar').toggle();
          		if($('#date-range-field a').text().charCodeAt(0) == 9660) {
            		$('#date-range-field a').html('&#9650;');
            		$('#date-range-field').css({borderBottomLeftRadius:0, borderBottomRightRadius:0});
            		$('#date-range-field a').css({borderBottomRightRadius:0});
          		}
          		else {
            		$('#date-range-field a').html('&#9660;');
            		$('#date-range-field').css({borderBottomLeftRadius:5, borderBottomRightRadius:5});
            		$('#date-range-field a').css({borderBottomRightRadius:5});
          		}
          		return false;
        	});
        
        	$('html').click(function() {
          		if($('#datepicker-calendar').is(":visible")) {
            		$('#datepicker-calendar').hide();
            		$('#date-range-field a').html('&#9660;');
            		$('#date-range-field').css({borderBottomLeftRadius:5, borderBottomRightRadius:5});
            		$('#date-range-field a').css({borderBottomRightRadius:5});
          		}
        	});
        
        	$('#datepicker-calendar').click(function(event){
          		event.stopPropagation();
        	});
		}

	});
	return 	(new daterangeView());
});