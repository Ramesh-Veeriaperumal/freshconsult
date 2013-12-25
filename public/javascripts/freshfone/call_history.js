var setCallDuration;
var setLocationIfUnknown,
	blockNumber;
(function ($) {
	"use strict";
	var $freshfoneCallHistory = $('.fresfone-call-history'),
		$filterSortForm = $('#SortFilterCalls'),
		$add_to_blacklist = $('.add_to_blacklist'),
		$filterCondition = $filterSortForm.find('[rel=filter]'),
		$callHistoryBody = $freshfoneCallHistory.find(".list-page-body"),
		$currentPageNumber = $filterSortForm.find("input[name=page]"),
		$filterContainer = $freshfoneCallHistory.find(".ff_item"),
		$currentNumber = $filterSortForm.find("input[name=number_id]");
	
	setCallDuration = function () {
		$(".call_duration").each(function () {
			if ($(this).data("time") === undefined) { return; }
			$(this).html($(this).data("time").toTime());
		});
	};
	
	setLocationIfUnknown = function () {
		$(".location_unknown").each(function () {
			var country = countryForE164Number("+" + $(this).data('number'));
			$(this).html(country);
		});
	};
	
	blockNumber = function (number) {
		var $blockedNumbers = $freshfoneCallHistory.find('.blacklist[data-number="' + number + '"]')
			.removeClass('blacklist')
			.addClass('blacklisted');
		$blockedNumbers.find('.blacklist-toggle').attr('title', freshfone.unblockNumberText);
	}

	function getFilterData() {
		var condition, container, operator, values;

		$filterCondition.empty();
		$filterContainer.map(function (index, ele) {
			condition = this.getAttribute("condition");
			container = this.getAttribute("container");
			operator  = this.getAttribute("operator");
			values  = this.getAttribute("values");
			if (values.blank()) { return true; }
			// see if data_hash is better
			setPostParam($filterCondition, ('wf_c' + index), condition);
			setPostParam($filterCondition, ('wf_o' + index), operator);
			setPostParam($filterCondition, ('wf_v' + index + '_' + index), values.toString());
		});
		$currentPageNumber.val(1);
		$filterSortForm.trigger('change');
	}

	function setDropdownValue(obj) {
		$(obj)
			.parents('.dropdown:first').find('.filter-name')
			.text($(obj).text());
	}

	// Ordering
	$freshfoneCallHistory.on("click", ".wf_order_type, .wf_order, .number_id", function (ev) {
		ev.preventDefault();
		$filterSortForm.find("input[name=" + this.className + "]")
			.val(this.getAttribute(this.className))
			.trigger("change");

		$freshfoneCallHistory
			.find("." + this.className + " .ticksymbol").remove();
		$(this).prepend($('<span class="icon ticksymbol"></span>'));

		if (this.className !== 'wf_order_type') { setDropdownValue(this); }
	});
	
	$freshfoneCallHistory.on("click", ".show_delete_number", function (ev) {
		ev.preventDefault();
		ev.stopPropagation();
		$freshfoneCallHistory.find(".deleted_numbers").slideDown();
		$(this).hide();
	});
	// Filtering
	$freshfoneCallHistory.on("click", ".wf_filter", function (ev) {
		ev.preventDefault();
		$filterContainer.attr("values", this.getAttribute(this.className));

		$freshfoneCallHistory
			.find("." + this.className + " .ticksymbol").remove();
		$(this).prepend($('<span class="icon ticksymbol"></span>'));

		setDropdownValue(this);

		getFilterData();
	});
	// Pagination
	$freshfoneCallHistory.on("click", ".pagination a", function (ev) {
		ev.preventDefault();
		$.scrollTo('#calls');
		$filterSortForm.find("input[name=page]")
			.val(getParameterByName("page", this.href))
			.trigger("change");
	});

	$filterSortForm.change(function () {
		$callHistoryBody.html("<div class='loading-box'></div>");
		$.ajax({
			url: freshfone.CALL_HISTORY_CUSTOM_SEARCH_PATH,
			dataType: "script",
			data: $(this).serializeArray(),
			success: function (script) {  }
		});
	});

	$freshfoneCallHistory.on('click', '.child_calls', function () {
		var parent = $(this).parents('tr');
		if ($(this).data('fetch') === undefined) {
			$(this).data('fetch', true);
			parent
				.after("<tr rel='loadingtr'><td colspan='8'><div class='loading-box'></div></td></tr>")
				.addClass('transfer_call');
			$.ajax({
				url: freshfone.CALL_HISTORY_CHILDREN_PATH,
				dataType: "script",
				data: {
					id : $(this).data('id'),
					number_id : $currentNumber.val()  },
				success: function (script) {
					$("[rel='loadingtr']").remove();
				},
				error: function (data) {
					$("[rel='loadingtr']").remove();
					$(this).removeData('fetch');
				}
			});
		} else {
			var children_class = parent.attr('id');
			parent.toggleClass('transfer_call');
			$('.' + children_class).toggle();
		}
	});

	$freshfoneCallHistory.on('click', '.create_freshfone_ticket', function (ev) {
		ev.preventDefault();

		if (freshfoneendcall === undefined) { return false; }
		freshfoneendcall.id = $(this).data("id");
		freshfoneendcall.inCall = false;
		freshfoneendcall.callerId = $(this).data("customer-id");
		freshfoneendcall.callerName = $(this).data("customer-name");
		freshfoneendcall.number = "+" + $(this).data("number");
		freshfoneendcall.date = $(this).data("date");
		freshfoneendcall.showEndCallForm();
	});


	$freshfoneCallHistory.on('click', '.blacklist', function (ev) {
		$('#open-blacklist-confirmation').trigger('click');
		$('#blacklist-confirmation .number')
			.text('+' + $(this).data('number'));
		$('#blacklist_number_number').val($(this).data('number'));
	});

	$freshfoneCallHistory.on('click', '.blacklisted', function (ev) {
		var number = $(this).data('number');
		$freshfoneCallHistory.find('.blacklisted[data-number="+' + number + '"]')
			.removeClass('blacklisted')
			.addClass('blacklist')
			.find('.blacklist-toggle')
			.addClass('sloading loading-tiny');
		$.ajax({
			url: '/freshfone/blacklist_number/destroy/' + number,
			method: 'POST',
			async: true,
			success: function (data) {
				$freshfoneCallHistory
					.find('.blacklist[data-number="+' + number + '"] .blacklist-toggle')
					.removeClass('sloading loading-tiny')
					.attr('title', freshfone.blockNumberText);
			},
			error: function (data) {
				$freshfoneCallHistory
					.find('.blacklist[data-number="+' + number + '"]')
					.addClass('blacklisted')
					.removeClass('blacklist')
					.find('blacklist-toggle')
					.removeClass('sloading loading-tiny');
			}
		});
	});


	$(document).ready(function () {
		setCallDuration();
		setLocationIfUnknown();
		threeSixtyPlayer.init();
	});

}(jQuery));