# Run with: rackup -s thin
# then browse to http://localhost:9292
# Or with: thin --ssl --ssl-key-file key.pem --ssl-cert-file cert.pem --ssl-disable-verify -p 1339 start -R config.ru
# then browse to http://localhost:3000
#
# Check Rack::Builder doc for more details on this file format:
#  http://rack.rubyforge.org/doc/classes/Rack/Builder.html
require 'rubygems'
require 'thin'
require 'json'
require 'redis'
require 'yaml'

app = proc do |env|
  hosts = YAML.load_file( 'hosts.yml' )["hosts"]

  req = Rack::Request.new(env)
  body = req.body.read

  param_sets = body.split('&')

  params = {}
  param_sets.each do |set|
    d = set.split('=')
    if d.size == 2
      params[d[0]] = d[1]
    end
  end

  redis = Redis.new

  # Response body has to respond to each and yield strings
  # See Rack specs for more info: http://rack.rubyforge.org/doc/files/SPEC.html

  body = "<html>"
  body += "\n<head>"
  body += "\n<title>Ping Plotter</title>"
  body += "\n<link rel=\"stylesheet\" href=\"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css\" integrity=\"sha384-1q8mTJOASx8j1Au+a5WDVnPi2lkFfwwEAa8hDDdjZlpLegxhjVME1fgjWPGmkzs7\" crossorigin=\"anonymous\">"
  body += "\n<script src=\"//www.google.com/jsapi\"></script>"

  body += "\n<script type=\"text/javascript\">"
  body += "\n      google.load(\"visualization\", \"1.1\", {packages:[\"bar\"]});"

  hosts.each_with_index do |h,i|
    body += "\n      google.setOnLoadCallback(drawChart_#{i});"
    body += "\n      function drawChart_#{i}() {"
    body += "\n        var data = new google.visualization.DataTable();"
    body += "\n        data.addColumn('date', '');"
    body += "\n        data.addColumn('number', 'Ping Duration');"
    body += "\n        data.addRows(["

    data = JSON.parse( redis.get( "pings-#{h}" ) )

    data.each do |d|
      body += "\n          [new Date(#{d[0]}000), #{d[2] * 1000}],"
    end

    body += "\n        ]);"
    body += "\n"
    body += "\n        var options = {"
    body += "\n            legend: {position: 'none'},"
    body += "\n            hAxis: { format: 'HH:mm:ss' },"
    body += "\n            vAxis: { viewWindowMode:'explicit', viewWindow: { min:0, max:300 } } ,"
    body += "\n            chart: { vAxis: { minValue: 0, maxValue: 300 } },"
    #body += "\n          chart: {"
    body += "\n            title: '#{h}',"
    body += "\n            subtitle: '',"
    #body += "\n          }"
    body += "\n        };"
    body += "\n"
    body += "\n        var chart = new google.charts.Bar(document.getElementById('columnchart_material_#{i}'));"
    body += "\n"
    body += "\n        chart.draw(data, google.charts.Bar.convertOptions(options));"
    body += "\n      }"
  end

  hosts.each_with_index do |h,i|
    body += "\n    setTimeout( function(){ drawChart_#{i}(); }, #{100 + (1000 * i)})"
  end

  body += "\n    </script>"

  body += "\n</head>"
  body += "\n<body>"
  body += "\n<div class=\"container\">"


  hosts.each_with_index do |h,i|
    body += "\n<div class=\"row\" style=\"margin-bottom: 2em;\"><div class=\"col-md-12\"><div id=\"columnchart_material_#{i}\" style=\"width: 100%; height: 250px;\"></div></div></div>"
  end

  body += "\n</div>"
  body += "\n</body>"
  body += "\n</html>"

  [
    200,                                        # Status code
    { 'Content-Type' => 'text/html' },         # Reponse headers
    body                                        # Body of the response
  ]
end

run app
