/*jslint browser: true, devel: true */
/*global  BarChart:true */

(function($){
	"use strict";

  	var BarChart = function(element, options){
  		this.element = element;
		this.options = $.extend({}, $.fn.barChart.defaults, options);
		this.data = this.options.data;
		this.svg = '';
		this.group = '';
		this.total = 0;
		this.dx = 0;
		this.dy = 0;
		this.width = this.options.width;
		this.height = this.options.height;

		this.init();
	};

	BarChart.prototype = {
	    init: function() {
			if( this.options.data.length > 0) {

				this.calculateTotal();
				this.sliceData();
				this.calculate();
				this.createSVG();
				this.createGroupe();
				this.createBar();
				this.createLabel();
		    	this.onresize();
		    } else {

		    	this.renderNoData();
		    }
		},
		sliceData: function () {

			if( this.options.sliceDataAfter != 0) {
				this.data = this.options.data.slice(0, this.options.sliceDataAfter);
			}
		},
		onresize: function() {
			$(window).on('resize', $.proxy(this.calculateWidth, this)); 
		},
		calculateTotal: function () {
			var _self = this;
				_self.total = 0;
				
			$.each(_self.options.data, function(index, val){
				_self.total += val.value;
			})
		},
		calculateWidth: function () {
			var _self = this;

			this.width = $(this.options.renderTo).width();

			this.calculate();

			this.svg.attr("width", this.width);

			this.group.selectAll('rect.backdrop').attr("width", function(d, i) {return _self.width});
			this.group.selectAll('rect.filledBar').attr("width", function(d, i) {return _self.width});
			this.group.selectAll('rect.bar').attr("width", function(d, i) {return (d.value /_self.total) * _self.width })

			this.group.selectAll('text.value').attr("x",function(d) {return _self.xscale(d.value) + _self.width - 5;})

			this.textEllipsis();
		},
		calculateHeight: function () {
			return this.data.length * 45;
		},
		calculate: function() {
			var self = this;

			this.width = this.options.width || $(this.options.renderTo).width();
			this.height = this.options.height || this.calculateHeight();

			this.dx = this.width / this.total;
			this.dy = this.height / this.data.length;

			this.yscale = d3.scale.linear()
							.domain([0, self.data.length])
							.range([0, self.height]);

			this.xscale = d3.scale.linear()
							.domain([0, d3.max(self.data, function(d) { return d.value; })])
							.range([0, 5]);
		},
		createSVG: function(){
			$(this.options.renderTo).empty(); // To remove sloadin at first time initializing
			this.svg = d3.select(this.options.renderTo)
						.append("svg")
						.attr("width", this.width)
						.attr("height", this.height);
		},
		createGroupe: function () {
			var _self = this;
			this.group = this.svg.selectAll(".barGroup")
					.data(_self.data, function(d, i) { return(d); })
					.enter().append("g")
					.attr("class", "g")
		},
		createBar: function() {
			var _self = this;
			this.group.append("rect")
				.on("click.barchart", function() {
				    d3.event.stopPropagation();
				    _self.clickEvent(d3.select(this).attr("referenceId"));
				})
				.attr('referenceId', function(d, i) {return  d.id;})
				.attr("class", function(d, i) {return "backdrop " + d.name;})
				.attr("x", function(d, i) {return 0;})
				.attr("y", function(d, i) {return _self.yscale(i)+1;})
				.attr("width", function(d, i) {return _self.width})
				.attr("fill", '#fff')
				.attr("height", 30);

			this.group.append("rect")
				.on("click.barchart", function() {
				    d3.event.stopPropagation();
				    _self.clickEvent(d3.select(this).attr("referenceId"));
				})
				.attr('referenceId', function(d, i) {return  d.id;})
				.attr("class", function(d, i) {return "filledBar " + d.name;})
				.attr("x", function(d, i) {return 0;})
				.attr("y", function(d, i) {return _self.yscale(i)+25;})
				.attr({'rx': 3, 'ry': 3})
				.attr("width", function(d, i) {return _self.width})
				.attr("fill", '#E8E8E8')
				.attr("height", 5);

			// bars
			this.group.append("rect")
				.on("click.barchart", function() {
				    d3.event.stopPropagation();
				    _self.clickEvent(d3.select(this).attr("referenceId"));
				})
				.attr('referenceId', function(d, i) {return  d.id;})
				.attr("class", function(d, i) {return "bar " + d.name;})
				.attr("x", function(d, i) {return 0;})
				.attr("y", function(d, i) {return _self.yscale(i)+25;})
				.attr("height", 5)
				.attr({'rx': 3, 'ry': 3})
				.transition()
				.duration(1000)
				.attr("width", function(d, i) {
					return (_self.total != 0) ? (d.value /_self.total) * _self.width : 0
				})
		},
		createLabel: function() {
			var _self = this;
			this.group.append("text")
				.on("click.barchart", function() {
				    d3.event.stopPropagation();
				    _self.clickEvent(d3.select(this).attr("referenceId"));
				})
				.attr('referenceId', function(d, i) {return  d.id;})
				.attr("class", function(d, i) {return "label " + d.name;})
				.attr("x", 0)
				.attr("y", function(d, i) {return _self.yscale(i)+18;})
				.text( function(d) {return d.name ;})
			
			// labels
			this.group.append("text")
				.on("click.barchart", function() {
				    d3.event.stopPropagation();
				    _self.clickEvent(d3.select(this).attr("referenceId"));
				})
				.attr('referenceId', function(d, i) {return  d.id;})
				.attr("class", function(d, i) {return "value " + d.value;})
				.attr("x",function(d) {return _self.width - 2;})
				.attr("y", function(d, i) {return _self.yscale(i)+20;})
				.attr("text-anchor","end")
				.text( function(d) {return  d.value ;})

			this.textEllipsis();
		},
		textEllipsis: function () {
			var self = this;

			$(this.group.selectAll('.label')).each(function (i, element) {
				var actualTextLength = $(element).text().length;
				var fullTextWidth = $(element).outerWidth();
				var desiredWidth = (self.width * 65) / 100;
				var desiredTextLength = actualTextLength * (desiredWidth / fullTextWidth)
				
				if(actualTextLength > desiredTextLength){
					var text = $(element).text()
					$(element).text(text.slice(0, desiredTextLength) + "…");
				}
			})
		},
		updateChartData: function(options) {
			this.options = $.extend({}, this.options, options);

			delete this.group;
			$(this.element).find('g').remove();

			this.calculateTotal();
			this.sliceData();
			this.calculate();

			this.createGroupe();
			this.createBar();
			this.createLabel();	

			this.svg.attr("height", this.height);
		},
		clickEvent: function(id) {
			this.options.callback.call(this,id); 
		},
		renderNoData: function() {
			// Move to options in Feature
			$(this.options.renderTo).append("<div class='no_data_to_display text-center muted'><i class='ficon-no-data fsize-72'></i></div>");
		},
		destroy: function () {
			delete this.group;
			$(this.element).off(".barchart").removeData("barChart");
		}
	}

	$.fn.barChart = function(option) {
        return this.each(function() {
            var $this = $(this),
            data      = $this.data("barChart"),
            options   = typeof option == "object" && option
            if (!data) $this.data("barChart", (data = new BarChart(this,options)))
            if (typeof option == "string") data[option]()   
        });
    }

    $.fn.barChart.defaults = {
		renderTo: '',
		name: '',
		data: [],
		width: '',
		height: '',
		sliceDataAfter: 0, 
		callback: function(){}
	}

})(window.jQuery);
