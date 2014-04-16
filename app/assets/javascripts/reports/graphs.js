"use strict";

$(function() {
  $('.graph').each(function(index) {
    var id = this.id.replace('graph_', '');
    addGraph(id);
  });
});

var GRAPH_CONF = {
  // Width and height of the graph are exclusive of margins
  max_width: 900,
  height: 240,
  margin: {top: 10, right: 30, bottom: 35, left: 40},

  max_bar_width: 85
};
// Set the maximum number of bars based on a desired minimum bar width:
GRAPH_CONF.max_n_bars = Math.floor(GRAPH_CONF.max_width / 25);

function addGraph(id) {
  var details = all_details[id];
  var graph = d3.select("#graph_" + id);

  if (details.choices !== undefined) {
      // slider
      sliderGraph(graph, details);
  } else {
      // WIP: not implemented yet.
      return;
  }
}

function sliderGraph(graph, details) {
  var values = details.choices;

  var n_choices = ((details.maximum_units - details.minimum_units) /
                   details.step) + 1;
  var n_bars = Math.min(n_choices, GRAPH_CONF.max_n_bars);
  var trial_bar_width = Math.floor(GRAPH_CONF.max_width / n_bars);
  var width = n_bars * Math.min(trial_bar_width, GRAPH_CONF.max_bar_width);

  var x_lin = d3.scale.linear()
      .domain([details.minimum_units, details.maximum_units])
      .range([0, width]);

  if (n_bars === n_choices) {
    // There is enough room for 1 bar per choice.  Use an ordinal
    // scale and a 1:1 mapping between bins and choices.
    var x = d3.scale.ordinal()
        .domain(d3.range(details.minimum_units,
                         details.maximum_units + details.step,
                         details.step))
        .rangeBands([0, width]);

    var data = d3.layout.histogram()
        .bins(d3.range(details.minimum_units,
                       details.maximum_units + details.step * 2,
                       details.step))
        (values);

    var bar_width = x.rangeBand();
  } else {
    // Too many choices.  Use a linear scale and max_n_bars bins.
    var x = x_lin;

    var data = d3.layout.histogram()
        .bins(x.ticks(GRAPH_CONF.max_n_bars))
        (values);

    var bar_width = x(data[0].dx);
  }

  var max_bin_value = d3.max(data, function(d) { return d.y; });
  var max_bin_percentage = max_bin_value / statistics.responses;
  var median = d3.median(values);

  var y_prescale = d3.scale.linear()
      .domain([0, max_bin_value])
      .range([0, max_bin_percentage]);

  var y = d3.scale.linear()
      .domain([0, max_bin_percentage])
      .range([GRAPH_CONF.height, 0]);

  var xAxis = d3.svg.axis()
      .scale(x)
      .orient("bottom");

  function makeYAxis() {
      return d3.svg.axis()
          .scale(y)
          .orient("left")
          .tickFormat(d3.format(".0%"));
  }

  var svg = graph.append("svg")
      .attr("width", width + GRAPH_CONF.margin.left + GRAPH_CONF.margin.right)
      .attr("height", GRAPH_CONF.height + GRAPH_CONF.margin.top +
            GRAPH_CONF.margin.bottom)
    .append("g")
      .attr("transform", "translate(" + GRAPH_CONF.margin.left + "," +
            GRAPH_CONF.margin.top + ")");

  var bar = svg.selectAll(".bar")
      .data(data)
    .enter().append("g")
      .attr("class", "bar")
      .attr("transform", function(d) {
        return "translate(" + x(d.x) + "," + y(y_prescale(d.y)) + ")";
      });

  var default_value = parseInt(details.default_value);
  bar.append("rect")
      .attr("class", function(d) {
          if (default_value >= d.x && default_value < d.x + d.dx) {
              return "default";
          }
          if (median >= d.x && median < d.x + d.dx) {
              return "median";
          }
          return "standard";
      })
      .attr("x", 1)
      .attr("width", bar_width - 1)
      .attr("height", function(d) {
          return GRAPH_CONF.height - y(y_prescale(d.y));
      });

  bar.append("text")
      .attr("dy", ".75em")
      .attr("y", 6)
      .attr("x", bar_width / 2)
      .attr("text-anchor", "middle")
      .text(function(d) { return d3.format(",.0f")(d.y); });

  svg.append("g")
      .attr("class", "y axis")
      .call(makeYAxis());

  svg.append("g")
      .attr("class", "grid")
      .call(makeYAxis()
          .ticks(5)
          .tickSize(-width, 0)
          .tickFormat(""));

  // Draw the X axis _after_ the grid lines
  svg.append("g")
      .attr("class", "x axis")
      .attr("transform", "translate(0," + GRAPH_CONF.height + ")")
      .call(xAxis);

  svg.append("text")
      .attr("x", width / 2)
      .attr("y", GRAPH_CONF.height + 30)
      .attr("text-anchor", "middle")
      .text(details.unit_name);

  if (n_choices > 2) {
      var mean_scaled = x_lin(parseFloat(details.mean_choice));
      svg.append("line")
          .attr("x1", mean_scaled)
          .attr("y1", GRAPH_CONF.height + 10)
          .attr("x2", mean_scaled)
          .attr("y2", 0)
          .attr("stroke-width", 3)
          .attr("stroke", "#777");
  }
}
