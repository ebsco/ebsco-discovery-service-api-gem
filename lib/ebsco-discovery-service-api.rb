require 'net/http'
require 'cgi'
require 'json'

# This is the first, barely tested pass at creating a set of Ruby functions to authenticate to, search, and retrieve from the EDS API.
# Once this gem is installed, you can find demo code that makes use of the gem here:
# http://www.lh2cc.net/dse/efrierson/ruby/eds-alpha-demo.zip

module EDSApi
	
	API_URL = "http://eds-api.ebscohost.com/"
	API_URL_S = "https://eds-api.ebscohost.com/"
	
	# Connection object. Does what it says. ConnectionHandler is what is usually desired and wraps auto-reonnect features, etc.
	class Connection

	  attr_accessor :auth_token, :session_token, :guest
	  attr_writer :userid, :password
	  
	  # Init the object with userid and pass.
		def uid_init(userid, password, profile, guest = 'y')
			@userid = userid
			@password = password
			@profile = profile
			@guest = guest
			return self
		end
		def ip_init(profile, guest = 'y')
			@profile = profile
			@guest = guest
			return self
		end
		# Auth with the server. Currently only uid auth is supported.
		
		###
		def uid_authenticate(format = :xml)
			# DO NOT SEND CALL IF YOU HAVE A VALID AUTH TOKEN
			xml = "<UIDAuthRequestMessage xmlns='http://www.ebscohost.com/services/public/AuthService/Response/2012/06/01'><UserId>#{@userid}</UserId><Password>#{@password}</Password></UIDAuthRequestMessage>"
			uri = URI "#{API_URL_S}authservice/rest/uidauth"
			req = Net::HTTP::Post.new(uri.request_uri)
			req["Content-Type"] = "application/xml"
			req["Accept"] = "application/json" #if format == :json
			req.body = xml
			https = Net::HTTP.new(uri.hostname, uri.port)
			https.read_timeout=10 
			https.use_ssl = true
			https.verify_mode = OpenSSL::SSL::VERIFY_NONE
			begin
			  doc = JSON.parse(https.request(req).body)
			rescue Timeout::Error, Errno::EINVAL, Net::ReadTimeout, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
			  about "No response from server"
			end
			if doc.has_key?('ErrorNumber')
			   raise "Bad response from server - error code #{result['ErrorNumber']}"
			else
			   @auth_token = doc['AuthToken']
			end			
		end
		def ip_authenticate(format = :xml)
			uri = URI "#{API_URL_S}authservice/rest/ipauth"
			req = Net::Http:Post.new(uri.request_uri)
			req["Accept"] = "application/json" #if format == :json
			https = Net::HTTP.new(uri.hostname, uri.port)
			https.read_timeout=10
			https.use_ssl = true
			https.verify_mode = OpenSSL::SSL::VERIFY_NONE
			begin
			  doc = JSON.parse(https.request(req).body)
			rescue Timeout::Error, Net::ReadTimeout, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
			  raise "No response from server"
			end
			@auth_token = doc['AuthToken']
		end
		# Create the session
		def create_session
			uri = URI "#{API_URL}edsapi/rest/createsession?profile=#{@profile}&guest=#{@guest}"
			req = Net::HTTP::Get.new(uri.request_uri)
			req['x-authenticationToken'] = @auth_token
			req['Accept'] = "application/json"
#			Net::HTTP.start(uri.hostname, uri.port) { |http|
#  			doc = JSON.parse(http.request(req).body)
#				return doc['SessionToken']
#			}
			Net::HTTP.start(uri.hostname, uri.port, :read_timeout => 10) { |http|
  			
  			begin
			  return http.request(req).body
			rescue Timeout::Error, Net::ReadTimeout, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
			  raise "No response from server"
			end
			}
		end
		# End the session
		def end_session(session_token)
			uri = URI "#{API_URL}edsapi/rest/endsession?sessiontoken=#{CGI::escape(session_token)}"
			req = Net::HTTP::Get.new(uri.request_uri)
			req['x-authenticationToken'] = @auth_token
			Net::HTTP.start(uri.hostname, uri.port, :read_timeout => 10) { |http|
  			begin
			  http.request(req)
			rescue Timeout::Error, Net::ReadTimeout, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
			  raise "No response from server"
			end
			}
			return true
		end
		# Run a search query, XML results are returned
        def search(options, format = :xml)
			uri = URI "#{API_URL}edsapi/rest/Search?#{options}"
			#return uri.request_uri
			req = Net::HTTP::Get.new(uri.request_uri)

			req['x-authenticationToken'] = @auth_token
			req['x-sessionToken'] = @session_token
			req['Accept'] = 'application/json' #if format == :json

			Net::HTTP.start(uri.hostname, uri.port, :read_timeout => 4) { |http|
  			begin
			  return http.request(req).body
			rescue Timeout::Error, Net::ReadTimeout, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
			  raise "No response from server"
			end
			}
        end
	  # Retrieve specific information
		def retrieve(dbid, an, highlightterms = "", ebookpreferredformat = "", format = :xml)
			uri = URI "#{API_URL}edsapi/rest/retrieve?dbid=#{dbid}&an=#{an}"
			if highlightterms != ""
				updateURI = uri.to_s
				updateURI = updateURI + "&highlightterms=#{highlightterms}"
				uri = URI updateURI
			end
			if ebookpreferredformat != ""
				updateURI = uri.to_s
				updateURI = updateURI + "&ebookpreferredformat=#{ebookpreferredformat}"
				uri = URI updateURI
			end
			req = Net::HTTP::Get.new(uri.request_uri)
			req['x-authenticationToken'] = @auth_token
			req['x-sessionToken'] = @session_token
			req['Accept'] = 'application/json' #if format == :json

			Net::HTTP.start(uri.hostname, uri.port, :read_timeout => 4) { |http|
  			begin
			  return http.request(req).body
			rescue Timeout::Error, Net::ReadTimeout, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
			  raise "No response from server"
			end
			}
		end
		# Info method
		def info(format = :xml)
			uri = URI "#{API_URL}edsapi/rest/Info"
			req = Net::HTTP::Get.new(uri.request_uri)
			req['x-authenticationToken'] = @auth_token
			req['x-sessionToken'] = @session_token
			req['Accept'] = 'application/json' #if format == :json
			Net::HTTP.start(uri.hostname, uri.port, :read_timeout => 4) { |http|
  			begin
			  return http.request(req).body
			rescue Timeout::Error, Net::ReadTimeout, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
			  raise "No response from server"
			end
			}
		end
	end
	# Handles connections - retries failed connections, passes commands along
	class ConnectionHandler < Connection
		attr_accessor :max_retries
		attr_accessor :session_token
		def initialize(max_retries = 2)
			@max_retries = max_retries
		end
		def show_session_token
		  return @session_token
		end
		def show_auth_token
		  return @auth_token
		end
		def create_session(auth_token = @auth_token, format = :xml)
			@auth_token = auth_token
  			result = JSON.parse(super())
			  if result.has_key?('ErrorNumber')
				return result.to_s
			  else
				@session_token = result['SessionToken']
			  	return result['SessionToken']
			  end
		end
		def search(options, session_token, auth_token, format = :xml)
			
			# temporary fix while API SI resolves
			# catches case where user navigates past result page 250 and applies facet/limiter
			if (options.index('&action=') && (options.index('&action=') > 0))
				if (options.index('&action=GoToPage(').nil? && options.index('&action=SetView(').nil?)
					if (options.index('&pagenumber=') && (options.index('&pagenumber=') > 0))
						beginSubstring = options.index('&pagenumber=') + 12
						currentpage = options[beginSubstring..-1]
						newOptions = options[0..beginSubstring-1]
						endSubstring = currentpage.index('&') - 1
						newOptionsEnd = currentpage[endSubstring+1..-1]
						options = newOptions + "1" + newOptionsEnd
					end
				end
			end
						
			attempts = 0
			@session_token = session_token
			@auth_token = auth_token
			loop do
				result = JSON.parse(super(options, format))
				if result.has_key?('ErrorNumber')
					case result['ErrorNumber']
					      when "108"
						      @session_token = self.create_session
						      result = JSON.parse(super(options, format))
					      when "109"
						      @session_token = self.create_session
						      result = JSON.parse(super(options, format))
					      when "104"
						      self.uid_authenticate(:json)
						      result = JSON.parse(super(options, format))
					      when "107"
						      self.uid_authenticate(:json)
						      result = JSON.parse(super(options, format))
					      else
						      return result	
					end
					unless result.has_key?('ErrorNumber')
						return result
					end
					attempts += 1
					if attempts >= @max_retries
					      return result
					end
				else
				      return result
				end
			end
		end
	        def info (session_token, auth_token, format= :xml)
		   attempts = 0
		   @auth_token = auth_token
		   @session_token = session_token
			loop do
			  result = JSON.parse(super(format)) # JSON Parse
			  if result.has_key?('ErrorNumber')
				  case result['ErrorNumber']
				  	when "108"
				  		@session_token = self.create_session
				  	when "109"
				  		@session_token = self.create_session
				  	when "104"
				  		self.uid_authenticate(:json)
					when "107"
						self.uid_authenticate(:json)
				  end
				  attempts += 1
				  if attempts >= @max_retries
				  	return result
				  end
			  else
			  	return result
			  end
	                end
	        end
	        def retrieve(dbid, an, highlightterms, ebookpreferredformat, session_token, auth_token, format = :xml)
			attempts = 0
			@session_token = session_token
			@auth_token = auth_token
			loop do
			  result = JSON.parse(super(dbid, an, highlightterms, ebookpreferredformat, format))
			  if result.has_key?('ErrorNumber')
				  case result['ErrorNumber']
				  	when "108"
				  		@session_token = self.create_session
				  	when "109"
				  		@session_token = self.create_session
				  	when "104"
				  		self.uid_authenticate(:json)
					when "107"
						self.uid_authenticate(:json)
				  end
				  attempts += 1
				  if attempts >= @max_retries
					return result
				  end
			  else
			  	return result
			  end
		  end
		end
	end
end

# Benchmark response times
def benchmark(q = false)
	start = Time.now
	connection = EDSApi::ConnectionHandler.new(2)
	connection.uid_init('USERID', 'PASSWORD', 'PROFILEID')
	connection.uid_authenticate(:json)
	puts((start - Time.now).abs) unless q
	connection.create_session
	puts((start - Time.now).abs) unless q
	connection.search('query-1=AND,galapagos+hawk', :json)
	puts((start - Time.now).abs) unless q
	connection.end_session
	puts((start - Time.now).abs) unless q
end

# Run benchmark with warm up run; only if file was called directly and not required
if __FILE__ == $0
	benchmark(true)
	benchmark
end