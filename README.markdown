# comscore_ruby

## what is it
comscore_ruby is a minimal Ruby wrapper to [comScore's SOAP API](https://api.comscore.com).  It follows a design policy similar to that of [sucker](https://rubygems.org/gems/sucker) built for Amazon's API.

comScore's API is closed, you have to be a paying customer in order to access the data.

## installation
    [sudo] gem install comscore_ruby

## initialization and authentication
comScore uses basic HTTP authentication so just provide your regular login details.

    client = ComScore::Client.new(
      username,
      password,
      :log => false,
      :wait_time => 1
    )
    
## usage
There are only two core methods for the client which doesn't try to "over architect a spaghetti API":

* `get_report` - used to...while get reports and
* `request` - more generic used to make any kind of request

For reference, I'd recommend keeping [comScore's SOAP API](https://api.comscore.com) open as you code to understand what services you have available to you.  Also ask them for their initial documentation which is absolutely horrible but at least their engineering staff is pretty helpful.

The response returned by either of these requests is actually a [savon](http://savonrb.com/) [request object](http://rubydoc.info/gems/savon/0.9.7/Savon/Client#request-instance_method) to allow for maximum flexibility.  You can do things with this that are particularly nice:

* `response.to_hash` which works well in most cases but has been known to be buggy with XML attributes (at least in Ruby 1.8.x)
* `response.doc` the Nokogiri XML document to allow for some pretty advanced XPATH

9x out of 10 you'll be able to use to_hash on a response but you will sometimes have need to query with XPATH due to how `to_hash` parses certain XML attributes in comScore's results.

## examples
    # Find all media within the Canadian dictionary (from 2 months ago) that match "The Globe And Mail"
    client.request(:key_measures, :fetch_media) do |xml|
      xml.parameterId("media")
      xml.fetchMediaQuery("xmlns" => "http://comscore.com/FetchMedia") {
        xml.SearchCritera(:ExactMatch => "false", :Critera => "The Globe And Mail")
      }
      xml.reportQuery("xmlns" => "http://comscore.com/ReportQuery") {
        xml.Parameter(:KeyId => "geo", :Value => ComScore::GEOGRAPHIES["Canada"])
        xml.Parameter(:KeyId => "loc", :Value => ComScore::LOCATIONS["Home and Work"])
        xml.Parameter(:KeyId => "timeType", :Value => ComScore::TIME_TYPES["Months"])
        xml.Parameter(:KeyId => "timePeriod", :Value => DateTime.now.to_date.to_comscore_time_period - 2)
        xml.Parameter(:KeyId => "mediaSetType", :Value => ComScore::MEDIA_SET_TYPES["Ranked Categories"])
      }
    end
    
    # Find all the categories (or media sets) within the Canadian dictionary (from 2 months ago)
    client.request(:key_measures, :discover_parameter_values) do |xml|
      xml.parameterId("mediaSet")
      xml.query(:xmlns => "http://comscore.com/ReportQuery") {
        xml.Parameter(:KeyId => "geo", :Value => ComScore::GEOGRAPHIES["Canada"])
        xml.Parameter(:KeyId => "timeType", :Value => ComScore::TIME_TYPES["Months"])
        xml.Parameter(:KeyId => "timePeriod", :Value => DateTime.now.to_date.to_comscore_time_period - 2)
        xml.Parameter(:KeyId => "mediaSetType", :Value => ComScore::MEDIA_SET_TYPES["Ranked Categories"])
      }
    end
    
    # Get a key measures report for the Community - Lifestyles category (778226) for August, 2011
    client.get_report(:key_measures,
      :geo => ComScore::GEOGRAPHIES["Canada"],
      :loc => ComScore::LOCATIONS["Home and Work"],
      :timeType => ComScore::TIME_TYPES["Months"],
      :timePeriod => Date.new(2011, 8),
      :mediaSet => 778226,
      :mediaSetType => ComScore::MEDIA_SET_TYPES["Ranked Categories"],
      :targetType => ComScore::TARGET_TYPES["Simple"],
      :targetGroup => ComScore::TARGET_GROUPS["Total Audience"],
      :measure => [ComScore::MEASURES["Total Unique Visitors (000)"]]
    )

## todo
* More support for other parameters: geographies, locations etc.  I'm Canadian, so I really only built it for the parameters I use and know of.
* Passing of a hash to the initializer for config options including username and password so you don't have to awkwardly set logging off after initialization.

## see also
My other client library [romniture](https://github.com/msukmanowsky/ROmniture) for those of you looking to pull data from Omniture as well.