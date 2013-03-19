!function( $ ) {

	$(function () {

		"use strict"

		$(".prime").on("change", function(ev){  	
			console.log("TEST")
			// _condition = !$(this).children("input").prop("checked")
  	// 		$(this).siblings(".nested-level").children("input").prop({ "checked": !_condition })
		})

		var date_today = new Date()

		$("#date_filter").on("change", function(ev){
			$("#datepicker").toggle($(this).val() == 4)
		})

		var dates = $( "#start_date, #end_date" ).datepicker({
			changeMonth: true, 
			changeYear: true,
			numberOfMonths: 1,
			maxDate: "today",
			onSelect: function( selectedDate ) {
				var option = this.id == "start_date" ? "minDate" : "maxDate",
					instance = $( this ).data( "datepicker" ),
					date = $.datepicker.parseDate(
						instance.settings.dateFormat ||
						$.datepicker._defaults.dateFormat,
						selectedDate, instance.settings );
				dates.not( this ).datepicker( "option", option, date )
				$(this).prop("date", date)
			}
		})

		$("#start_date").val((date_today.getMonth()) + '/' + date_today.getDate() + '/' + date_today.getFullYear());
		$("#end_date").val((date_today.getMonth()+1) + '/' + date_today.getDate() + '/' + date_today.getFullYear());
	})

}(window.jQuery)