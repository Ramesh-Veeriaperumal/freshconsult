(function($){
    "use strict";

    var ProgressChart = function(options){
        this.options = $.extend({}, $.fn.progressChart.defaults, options);
        this.svg = '',
        this.arc = '',
        this.meter = '',
        this.twoPi = 2 * Math.PI,
        this.progress = 0,
        this.formatPercent = d3.format(".0%"),
        this.calc_percent = 0

        this.init();
    }

    ProgressChart.prototype = {
        init: function () {
            if(this.options.data.value != null && this.options.data.value != '') {
                this.calc_percent = ( this.options.data.value / this.options.data.total ) * 100;

                this.createArc();
                this.createSVG();
                this.createMeter();
                this.createForegtound();
                this.interpolate();
            } else {
                this.renderNoData();
            }
        },
        createSVG: function () {
            this.svg = d3.select(this.options.renderTo)
                        .append("svg")
                        .attr("width", this.options.width)
                        .attr("height", this.options.height)
                        .append("g")
                        .attr("transform", "translate(" + this.options.width / 2 + "," +  this.options.height / 2 + ")");

        },
        createArc: function () {
            this.arc = d3.svg.arc()
                            .startAngle(0)
                            .innerRadius(this.options.width / 2)
                            .outerRadius(this.options.width / 3);

        },
        createMeter: function () {
            var self = this;
            this.meter = this.svg.append("g")
                .attr("class", "progress-meter");

            this.meter.append("path")
                .attr("class", "background")
                .attr("d", self.arc.endAngle(self.twoPi));

            this.meter.append("text")
                .attr("text-anchor", "middle")
                .attr("dy", "0.5em")
                .text(this.options.data.value)
        },
        createForegtound: function () {
            this.foreground = this.meter.append("path")
                .attr("class", "foreground");
        },
        interpolate: function () {
            var self = this;
            var i = d3.interpolate(self.progress, self.calc_percent / 100);
            
            d3.transition().tween("progress", function() {
                return function(t) {
                    self.progress = i(t);
                    self.foreground.attr("d", self.arc.endAngle(self.twoPi * self.progress));
                    self.meter.transition().delay(500)
                };
            });
        },
        renderNoData: function() {
            // Move to options in Feature
            $(this.options.renderTo).append("<div class='no_data_to_display text-center muted'><i class='ficon-no-data fsize-48'></i></div>");
        }
    }

    $.fn.progressChart = function(option) {
        return this.each(function() {
            var $this = $(this),
            data      = $this.data("progressChart"),
            options   = typeof option == "object" && option
            if (!data) $this.data("progressChart", (data = new ProgressChart(this,options)))
            if (typeof option == "string") data[option]()   
        });
    }

    $.progressChart = function (option) {
        var options = typeof option == 'object' && option,
            progressChart = new ProgressChart(options);

        return(progressChart);
    }

    $.fn.progressChart.defaults = { 
        renderTo: '#progressChart',
        data: {
            label: "",
            value: 0,
            total: 0
        },
        width: 100,
        height: 100
    }


})(window.jQuery);