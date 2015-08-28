var FreshfoneContactSearch;
(function ($) {
    "use strict";
  var regex = /^.*[a-zA-Z].*|.*\d.*$/,
  	 specCharRegex = /^[a-zA-Z0-9]*$/;
  FreshfoneContactSearch = function () {
	   this.$container = $('#search_bar');
		this.init();
	};

	FreshfoneContactSearch.prototype = {
		init: function () {
			this.$searchList = this.$container.find('.contact_results_info');
			this.$searchedNumber = this.$searchList.find('.searched-number');

			this.bindSearchList();
			this.bindSearchedNumber();
		},

		bindSearchList: function(){
			var self = this;
			this.$searchList.on('mouseover', '.search-result', function(){
			 	var $prevElem = self.$searchList.find('.active-element');	
				freshfoneDialpadEvents.makeActive($prevElem,$(this)); 	

	  	}).on('click', '.search-result', function(){
		    var $parentElem = $(this).parents('li'),
		    	 freshfone_number = $(this).find(".phone-contact").text().trim();
		    freshfoneDialpadEvents.updateNumber(freshfone_number,$parentElem);
			});
		},

		bindSearchedNumber: function(){
			this.$container.on('click', '.searched-number', function(){
				if( $(this).hasClass('make-call')) {
					return freshfonecalls.makeCall($(this).parents("li"));	
				}
			}).on('mouseover', '.searched-number', function(){
				$(this).addClass("active-element");

		  }).on('mouseleave', '.searched-number', function(){
		    $(this).removeClass("active-element");
		  });	
		},

		isValidSearchString: function(searchString){
			return (searchString.length >= 2 && regex.test(searchString))
		},

		replaceSpecChar: function(result_string){
			if(!specCharRegex.test(result_string)){
				result_string = result_string.replace(result_string.charAt(0),'');
			}
			return result_string;
		},

		getSearchResults: function(string){
		  var self = this;
		  $.ajax({ 
	  		url: '/freshfone/autocomplete/customer_contact',
	  		method: 'GET',
	  		allowClear: true,
	  		data: { q: string },
	  		dataType : "html",
				success: function(data){
					self.$searchList.html(data);
					self.appendNoResults(string);
					if(self.$searchList.is(':visible')){
						self.$searchList.find('li :first').find('.contact-num li :first').addClass('active-element');
					}
				}
			});	
		},

		appendNoResults: function(string){
			var regex = /[a-zA-Z]/;
			this.$container.show();
			if(regex.test(string)){
				$('.no_results').text("No results found");
			}else{
				var phone_icon = '<div class="ff_call_button pull-right"><i class="ficon-ff-phone fsize-11 " size="11"></i> Call </div>';
				$('.no_results').text(string);
				$('.searched-number')
						.addClass('make-call')
						.append(phone_icon);
			}	
	  }
	};

}(jQuery));