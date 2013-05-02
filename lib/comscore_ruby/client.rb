module ComScore
  class Client
    BASE_URI = "https://api.comscore.com/"
    DEFAULT_REPORT_WAIT_TIME = 5
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
    
    def initialize(username, password, options={})
      @username   = username
      @password   = password
      @wait_time  = options[:wait_time] ? options[:wait_time] : DEFAULT_REPORT_WAIT_TIME
      self.log    = options[:log] ? options[:log] : false
      
      
      @client = Savon::Client.new
      @client.http.auth.basic(@username, @password)
    end
    
    # Executes a request against ComScore's SOAP API.  Service name should correspond to one of the available services you've subscribed to:
    # - +:key_measures+
    # - +:audience_duplication+
    # - +:percent_media_trend+
    # - etc... see http://api.comscore.com for more information
    # You can (and should) pass a block to build the details of the request you're sending to the method.  See the examples below.
    #
    # == Examples
    #
    #   # Find the media property named "The Globe And Mail" within the Canadian dictionary from two months ago.
    #   client = ComScore::Client.new(username, password)
    #   client.request(:key_measures, :fetch_media) do |xml|
    #     xml.parameterId("media")
    #     xml.fetchMediaQuery("xmlns" => "http://comscore.com/FetchMedia") {
    #       xml.SearchCritera(:ExactMatch => "false", :Critera => "The Globe And Mail")
    #     }
    #     xml.reportQuery("xmlns" => "http://comscore.com/ReportQuery") {
    #       xml.Parameter(:KeyId => "geo", :Value => ComScore::GEOGRAPHIES["Canada"])
    #       xml.Parameter(:KeyId => "loc", :Value => ComScore::LOCATIONS["Home and Work"])
    #       xml.Parameter(:KeyId => "timeType", :Value => ComScore::TIME_TYPES["Months"])
    #       xml.Parameter(:KeyId => "timePeriod", :Value => DateTime.now.to_date.to_comscore_time_period - 2)
    #       xml.Parameter(:KeyId => "mediaSetType", :Value => ComScore::MEDIA_SET_TYPES["Ranked Categories"])
    #     }
    #   end
    def request(service_name, method)
      @client.wsdl.document = @client.wsdl.endpoint = SERVICES[service_name][:wsdl]

      @client.request(method) do
        soap.xml do |xml|
          xml.soap(:Envelope, "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance", "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema", "xmlns:soap" => "http://schemas.xmlsoap.org/soap/envelope/") {
            xml.soap(:Body) {
              xml.tag!(method.to_s.camelize, :xmlns => "http://comscore.com/") {
                yield xml if block_given?
              }
            }
          }
        end
      end
    end
    
    # Fetches report data against a given comScore +service+ (e.g. KeyMeasures, MediaTrend, etc).
    #
    # == Examples
    #
    #   # Get a Key Measures report for a given media set ID
    #   client.get_report(:key_measures,
    #    :geo => ComScore::GEOGRAPHIES["Canada"],
    #    :loc => ComScore::LOCATIONS["Home and Work"],
    #    :timeType => ComScore::TIME_TYPES["Months"],
    #    :timePeriod => Date.new(2011, 8),
    #    :mediaSet => 778226,
    #    :mediaSetType => ComScore::MEDIA_SET_TYPES["Ranked Categories"],
    #    :targetType => ComScore::TARGET_TYPES["Simple"],
    #    :targetGroup => ComScore::TARGET_GROUPS["Total Audience"],
    #    :measure => [ComScore::MEASURES["Total Unique Visitors (000)"]]
    #   )
    def get_report(service, opts = {})
      job_queue_response = self.request(service, :submit_report) do |xml|
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
      end
      
      job_id = job_queue_response.to_hash()[:submit_report_response][:submit_report_result][:job_id]
      job_status = ""
      
      begin
        sleep(@wait_time) if job_status != ""
        job_status_response = self.request(service, :ping_report_status) { |xml| xml.jobId(job_id) }.to_hash
        job_status = job_status_response[:ping_report_status_response][:ping_report_status_result][:status]
      end while (job_status != "Completed" && job_status != "Failed")
      
      if job_status == "Completed"
        return self.request(service, :fetch_report) {|xml| xml.jobId(job_id) }
      else
        raise "The job with id #{job_id} failed to complete. Last known status was #{job_status}."
      end
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
      
  end
end