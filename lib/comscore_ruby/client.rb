module ComScore
  class Client
    BASE_URI = "https://api.comscore.com/"
    SERVICES = {
      :key_measures         => {:wsdl => "#{BASE_URI}KeyMeasures.asmx?WSDL"},
      :audience_duplication => {:wsdl => "#{BASE_URI}DigitalCalc.asmx?WSDL"},
      :percent_media_trend  => {:wsdl => "#{BASE_URI}PercentMediaTrend.asmx?WSDL"},
      :percent_target_trend => {:wsdl => "#{BASE_URI}PercentTargetTrend.asmx?WSDL"},
      :demographic_profile  => {:wsdl => "#{BASE_URI}DemographicProfile.asmx?WSDL"},
      :media_trend          => {:wsdl => "#{BASE_URI}MediaTrend.asmx?WSDL"},
      :target_trend         => {:wsdl => "#{BASE_URI}TargetTrend.asmx?WSDL"},
      :cross_visit          => {:wsdl => "#{BASE_URI}CrossVisit.asmx?WSDL"},
      :video_key_measures   => {:wsdl => "#{BASE_URI}VideoMetrix/VideoMetrixKeyMeasures.asmx?WSDL"},
      :video_media_trend    => {:wsdl => "#{BASE_URI}VideoMetrix/VideoMetrixMediaTrend.asmx?WSDL"},
      :video_demographic_profile => {:wsdl => "#{BASE_URI}VideoMetrix/VideoMetrixDemographicProfile.asmx?WSDL"},
      :mobilens_audience_profile => {:wsdl => "#{BASE_URI}MobiLens/AudienceProfile.asmx?WSDL"},
      :mobilens_trend       => {:wsdl => "#{BASE_URI}MobiLens/Trend.asmx?WSDL"}
    }
    
    def initialize(uname, pw)
      @username, @password = [uname, pw]
    end
    
    def log=(value)
      raise ArgumentError, "Parameter must be of type Boolean." unless !!value == value
      @log = value
      Savon.configure do |config|
        config.log = value
        config.log_level = :info if value == false
      end
      HTTPI.log = value
    end
    
    def log
      @log
    end
    
    def media_sets
      @client = Savon::Client.new(SERVICES[:key_measures][:wsdl])
      @client.http.auth.basic(@username, @password)
      
      response = @client.request(:discover_parameter_values) do
        soap.xml do |xml|
          xml.soap(:Envelope, "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance", "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema", "xmlns:soap" => "http://schemas.xmlsoap.org/soap/envelope/") {
            xml.soap(:Body) {
              xml.DiscoverParameterValues(:xmlns => "http://comscore.com/") {
                xml.parameterId("mediaSet")
                xml.query(:xmlns => "http://comscore.com/ReportQuery") {
                  xml.Parameter(:KeyId => "geo", :Value => "124")
                  xml.Parameter(:KeyId => "timeType", :Value => "1")
                  xml.Parameter(:KeyId => "timePeriod", :Value => DateTime.now.to_date.to_comscore_time_period - 2)
                  xml.Parameter(:KeyId => "mediaSetType", :Value => "1")
                }
              }
            }
          }
        end
      end
      
      response.to_hash()[:discover_parameter_values_response][:discover_parameter_values_result][:enum_value]
    end
    
    def find_media(criterion = [])
      @client = Savon::Client.new(SERVICES[:key_measures][:wsdl])
      @client.http.auth.basic(@username, @password)
      response = @client.request(:fetch_media) do
        soap.xml do |xml|
          xml.soap(:Envelope, "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance", "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema", "xmlns:soap" => "http://schemas.xmlsoap.org/soap/envelope/") {
            xml.soap(:Body) {
              xml.FetchMedia("xmlns" => "http://comscore.com/") {
                xml.parameterId("media")
                xml.fetchMediaQuery("xmlns" => "http://comscore.com/FetchMedia") {
                  criterion.each do |criteria|
                    xml.SearchCritera(:ExactMatch => "false", :Critera => criteria)
                  end
                } if criterion.count > 0
                xml.reportQuery("xmlns" => "http://comscore.com/ReportQuery") {
                  xml.Parameter(:KeyId => "geo", :Value => "124")
                  xml.Parameter(:KeyId => "loc", :Value => "0")
                  xml.Parameter(:KeyId => "timeType", :Value => "1")
                  xml.Parameter(:KeyId => "timePeriod", :Value => DateTime.now.to_date.to_comscore_time_period - 2)
                  xml.Parameter(:KeyId => "mediaSetType", :Value => "1")
                }
              }
            }
          }
        end
      end
      
      response.to_hash()[:fetch_media_response][:fetch_media_result][:media_item]
    end
        
    # Requires: geo, loc, timeType, timePeriod, mediaSetType
    # Usage: find_media(:geo => "Canada", :loc => "")
    def get_report(report_type, opts = {})
      @client = Savon::Client.new(SERVICES[report_type][:wsdl])
      @client.http.auth.basic(@username, @password)
      job_queue_response = @client.request(:submit_report) do
        soap.xml do |xml|
          xml.soap(:Envelope, "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance", "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema", "xmlns:soap" => "http://schemas.xmlsoap.org/soap/envelope/") {
            xml.soap(:Body) {
              xml.SubmitReport("xmlns" => "http://comscore.com/") {
                xml.query("xmlns" => "http://comscore.com/ReportQuery") {
                  opts.each { |key, value|
                    if value.is_a?(Array)
                      value.each do |v|
                        xml.Parameter(:KeyId => key, :Value => v)
                      end
                    elsif value.is_a?(Date)
                      xml.Parameter(:KeyId => key, :Value => value.to_comscore_time_period)
                    else
                      xml.Parameter(:KeyId => key, :Value => value)
                    end
                  }
                }
              }
            }
          }
        end
      end
      
      job_id = job_queue_response.to_hash()[:submit_report_response][:submit_report_result][:job_id]
      
      job_status = "Starting"
      begin
        sleep(2) if job_status == "Starting"
        job_status_response = @client.request(:ping_report_status) do
          soap.xml do |xml|
            xml.soap(:Envelope, "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance", "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema", "xmlns:soap" => "http://schemas.xmlsoap.org/soap/envelope/") {
              xml.soap(:Body) {
                xml.PingReportStatus("xmlns" => "http://comscore.com/") {
                  xml.jobId(job_id)
                }
              }
            }
          end
        end
        job_status = job_status_response.to_hash()[:ping_report_status_response][:ping_report_status_result][:status]
      end while (job_status != "Completed" && job_status != "Failed")
      
      if (job_status == "Completed") 
        result = @client.request(:fetch_report) do
          soap.xml do |xml|
            xml.soap(:Envelope, "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance", "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema", "xmlns:soap" => "http://schemas.xmlsoap.org/soap/envelope/") {
              xml.soap(:Body) {
                xml.FetchReport("xmlns" => "http://comscore.com/") {
                  xml.jobId(job_id)
                }
              }
            }
          end
        end          
        return result.to_hash()[:fetch_report_response][:fetch_report_result]
      else
        raise "The job with id #{job_id} failed to complete. Last known status was #{job_status}."
      end
    end
    
  end
end