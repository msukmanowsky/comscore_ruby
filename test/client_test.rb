require 'rubygems'
require 'test/unit'
require 'yaml'

require 'comscore_ruby'

class ClientTest < Test::Unit::TestCase
  
  def setup
    @config = YAML::load(File.open("test/config.yml"))["comscore"]
    
    @client = ComScore::Client.new(@config["username"], @config["password"])
    @client.log = false
  end
  
  def test_fetch_media
    response = @client.request(:key_measures, :fetch_media) do |xml|
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
    
    assert_equal("The Globe And Mail", response.to_hash[:fetch_media_response][:fetch_media_result][:media_item][:@name])
  end
  
  def test_category_list
    response = @client.request(:key_measures, :discover_parameter_values) do |xml|
      xml.parameterId("mediaSet")
      xml.query(:xmlns => "http://comscore.com/ReportQuery") {
        xml.Parameter(:KeyId => "geo", :Value => ComScore::GEOGRAPHIES["Canada"])
        xml.Parameter(:KeyId => "timeType", :Value => ComScore::TIME_TYPES["Months"])
        xml.Parameter(:KeyId => "timePeriod", :Value => DateTime.now.to_date.to_comscore_time_period - 2)
        xml.Parameter(:KeyId => "mediaSetType", :Value => ComScore::MEDIA_SET_TYPES["Ranked Categories"])
      }
    end
    
    assert_instance_of(Array, response.to_hash[:discover_parameter_values_response][:discover_parameter_values_result][:enum_value])
  end
  
  def test_key_measures
    response = @client.get_report(:key_measures,
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
    
    assert_instance_of(Array, response.to_hash[:fetch_report_response][:fetch_report_result][:report][:table][:tbody][:tr])
  end
  
end