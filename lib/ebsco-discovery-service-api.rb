require 'net/http'
require 'cgi'
require 'json'

#TO DO: Finish publication Exact Match object - probably needs to be a subclass of EDSAPIRecord
#TO DO: Finish Detailed Records

module EDSApi

	API_URL = "http://eds-api.ebscohost.com/"
	API_URL_S = "https://eds-api.ebscohost.com/"

	class EDSAPIRecord

		attr_accessor :record

		def initialize(results_record)
			@record = results_record;
		end

		def an
			@record["Header"]["An"]
		end

		def dbid
			@record["Header"]["DbId"]
		end

		def plink
			@record["Header"]["PLink"]
		end

		def score
			@record["Header"]["RelevancyScore"]
		end

		def pubtype
			@records["Header"]["PubType"]
		end

		def pubtype_id
			@records["Header"]["PubTypeId"]
		end

		def title
			items = @record.fetch('Items',{})
			if items.count > 0
				items.each do |item|
					if item["Group"] == "Ti"
						return item["Data"]
					end
				end
			end

			titles = @record.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibEntity', {}).fetch('Titles', {})
			if titles.count > 0
				titles.each do |title|
					if title["Type"] == "main"
						return title["TitleFull"]
					end
				end
			end

			return "Title not available"
		end

		def title_raw
			titles = @record.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibEntity', {}).fetch('Titles', {})
			if titles.count > 0
				titles.each do |title|
					if title["Type"] == "main"
						return title["TitleFull"]
					end
				end
			end
			items = @record.fetch('Items',{})
			if items.count > 0
				items.each do |item|
					if item["Group"] == "Ti"
						return item["Data"]
					end
				end
			end
			return "Title not available"
		end
		#end title_raw

		def source
			items = @record.fetch('Items',{})
			if items.count > 0
				items.each do |item|
					if item["Group"] == "Src"
						full_source = item["Data"]
					end
				end
			end
			return nil
		end

		def pubyear
			ispartofs = @record.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibRelationships', {}).fetch('IsPartOfRelationships', {})
			if ispartofs.count > 0
				dates = ispartofs[0]["BibEntity"].fetch('Dates',{})
				if dates.count > 0
					dates.each do |date|
						if date["Type"] == "published"
							return date["Y"]
						end
					end
				end
			end
			return nil
		end

		def pubdate
			ispartofs = @record.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibRelationships', {}).fetch('IsPartOfRelationships', {})
			if ispartofs.count > 0
				dates = ispartofs[0]["BibEntity"].fetch('Dates',{})
				if dates.count > 0
					dates.each do |date|
						if date["Type"] == "published"
							return date["Y"]+"-"+date["M"]+"-"+date["D"]
						end
					end
				end
			end
			return nil
		end

		def all_links
			links = self.fulltext_links
			links = links + self.nonfulltext_links
			return links
		end

		def fulltext_links

			links = []

			ebscolinks = @record.fetch('FullText',{}).fetch('Links',{})
			if ebscolinks.count > 0
				ebscolinks.each do |ebscolink|
					if ebscolink["Type"] == "pdflink"
						link_label = "PDF Full Text"
						link_icon = "PDF Full Text Icon"
						if ebscolink.key?("Url")
							link_url = ebscolink["Url"]
						else
							link_url = "detail";
						end
						links.push({url: link_url, label: link_label, icon: link_icon, type: "pdf"})
					end
				end
			end

			htmlfulltextcheck = @record.fetch('FullText',{}).fetch('Text',{}).fetch('Availability',0)
			if htmlfulltextcheck == "1"
				link_url = "detail"
				link_label = "Full Text in Browser"
				link_icon = "Full Text in Browser Icon"
				links.push({url: link_url, label: link_label, icon: link_icon, type: "html"})
			end

			if ebscolinks.count > 0
				ebscolinks.each do |ebscolink|
					if ebscolink["Type"] == "ebook-pdf"
						link_label = "PDF eBook Full Text"
						link_icon = "PDF eBook Full Text Icon"
						if ebscolink.key?("Url")
							link_url = ebscolink["Url"]
						else
							link_url = "detail";
						end
						links.push({url: link_url, label: link_label, icon: link_icon, type: "ebook-pdf"})
					end
				end
			end

			if ebscolinks.count > 0
				ebscolinks.each do |ebscolink|
					if ebscolink["Type"] == "ebook-epub"
						link_label = "ePub eBook Full Text"
						link_icon = "ePub eBook Full Text Icon"
						if ebscolink.key?("Url")
							link_url = ebscolink["Url"]
						else
							link_url = "detail";
						end
						links.push({url: link_url, label: link_label, icon: link_icon, type: "ebook-epub"})
					end
				end
			end

			items = @record.fetch('Items',{})
			if items.count > 0
				items.each do |item|
					if item["Group"] == "URL"
						if item["Data"].include? "linkTerm=&quot;"
							link_start = item["Data"].index("linkTerm=&quot;")+15;
							link_url = item["Data"][link_start..-1]
							link_end = link_url.index("&quot;")-1
							link_url = link_url[0..link_end]
							link_label_start = item["Data"].index("link&gt;")+8
							link_label = item["Data"][link_label_start..-1]
							link_label = link_label.strip
						else
							link_url = item["Data"]
							link_label = item["Label"]
						end
						link_icon = "Catalog Link Icon"
						links.push({url: link_url, label: link_label, icon: link_icon, type: "cataloglink"})
					end
				end
			end

			if ebscolinks.count > 0
				ebscolinks.each do |ebscolink|
					if ebscolink["Type"] == "other"
						link_label = "Linked Full Text"
						link_icon = "Linked Full Text Icon"
						if ebscolink.key?("Url")
							link_url = ebscolink["Url"]
						else
							link_url = "detail";
						end
						links.push({url: link_url, label: link_label, icon: link_icon, type: "smartlinks+"})
					end
				end
			end

			ft_customlinks = @record.fetch('FullText',{}).fetch('CustomLinks',{})
			if ft_customlinks.count > 0
				ft_customlinks.each do |ft_customlink|
					link_url = ft_customlink["Url"]
					link_label = ft_customlink["Text"]
					link_icon = ft_customlink["Icon"]
					links.push({url: link_url, label: link_label, icon: link_icon, type: "customlink-fulltext"})
				end
			end

			return links
		end

		def nonfulltext_links
			links = []
			other_customlinks = @record.fetch('CustomLinks',{})
			if other_customlinks.count > 0
				other_customlinks.each do |other_customlink|
					link_url = other_customlink["Url"]
					link_label = other_customlink["Text"]
					link_icon = other_customlink["Icon"]
					links.push({url: link_url, label: link_label, icon: link_icon, type: "customlink-other"})
				end
			end

			return links
		end

		def best_fulltext_link
			if self.fulltext_links.count > 0
				return self.fulltext_links[0]
			end
			return {}
		end

	end

	class EDSAPIResponse

		attr_accessor :results, :records, :dblabel, :researchstarters, :publicationmatch, :debug

		def initialize(search_results)
			@debug = ""
			@results = search_results
			if hitcount > 0
				@records = []
				search_results["SearchResult"]["Data"]["Records"].each do |record|
					@records.push(EDSApi::EDSAPIRecord.new(record))
				end
			else
				@records = []
			end

			@researchstarters = []
			relatedrecords = @results.fetch('SearchResult',{}).fetch('RelatedContent',{}).fetch('RelatedRecords',{})
			if relatedrecords.count > 0
				relatedrecords.each do |related_item|
					if related_item["Type"] == "rs"
						rs_entries = related_item.fetch('Records',{})
						if rs_entries.count > 0
							rs_entries.each do |rs_record|
								@researchstarters.push(EDSApi::EDSAPIRecord.new(rs_record))
							end
						end
					end
				end
			end

			@publicationmatch = []
			relatedpublications = @results.fetch('SearchResult',{}).fetch('RelatedContent',{}).fetch('RelatedPublications',{})
			if relatedpublications.count > 0
				relatedpublications.each do |related_item|
					if related_item["Type"] == "emp"
						publicationmatches = related_item.fetch('PublicationRecords',{})
						if publicationmatches.count > 0
							publicationmatches.each do |publication_record|
								@publicationmatch.push(EDSApi::EDSAPIRecord.new(publication_record))
							end
						end
					end
				end
			end

			@dblabel = {}
			@dblabel["EDB"] = "Publisher Provided Full Text Searching File"
			@dblabel["EDO"] = "Supplemental Index"
			@dblabel["ASX"] = "Academic Search Index"
			@dblabel["A9H"] = "Academic Search Complete"
			@dblabel["APH"] = "Academic Search Premier"
			@dblabel["AFH"] = "Academic Search Elite"
			@dblabel["A2H"] = "Academic Search Alumni Edition"
			@dblabel["ASM"] = "Academic Search Main Edition"
			@dblabel["ASR"] = "STM Source"
			@dblabel["BSX"] = "Business Source Index"
			@dblabel["EDSEBK"] = "Discovery eBooks"
			@dblabel["VTH"] = "Art & Architecture Complete"
			@dblabel["IIH"] = "Computers & Applied Sciences Complete"
			@dblabel["CMH"] = "Consumer Health Complete - CHC Platform"
			@dblabel["C9H"] = "Consumer Health Complete - EBSCOhost"
			@dblabel["EOAH"] = "E-Journals Database"
			@dblabel["EHH"] = "Education Research Complete"
			@dblabel["HCH"] = "Health Source: Nursing/Academic"
			@dblabel["HXH"] = "Health Source: Consumer Edition"
			@dblabel["HLH"] = "Humanities International Complete"
			@dblabel["LGH"] = "Legal Collection"
			@dblabel["SLH"] = "Sociological Collection"
			@dblabel["CPH"] = "Computer Source"
			@dblabel["PBH"] = "Psychology & Behavioral Sciences Collection"
			@dblabel["RLH"] = "Religion & Philosophy Collection"
			@dblabel["NFH"] = "Newspaper Source"
			@dblabel["N5H"] = "Newspaper Source Plus"
			@dblabel["BWH"] = "Regional Business News"
			@dblabel["OFM"] = "OmniFile Full Text Mega"
			@dblabel["RSS"] = "Rehabilitation & Sports Medicine Source"
			@dblabel["SYH"] = "Science & Technology Collection"
			@dblabel["SCF"] = "Science Full Text Select"
			@dblabel["HEH"] = "Health Business Elite"
		end

		def hitcount
			@results["SearchResult"]["Statistics"]["TotalHits"]
		end

		def searchtime
			@results["SearchResult"]["Statistics"]["TotalSearchTime"]
		end

		def database_stats
			databases = []
			databases_facet = @results["SearchResult"]["Statistics"]["Databases"]
			databases_facet.each do |database|
				if @dblabel.key?(database["Id"].upcase)
					db_label = @dblabel[database["Id"].upcase];
				else
					db_label = database["Label"]
				end
				databases.push({id: database["Id"], hits: database["Hits"], label: db_label})
			end
			return databases
		end

		def facets (facet_provided_id = "all")
			facets_hash = []
			available_facets = @results.fetch('SearchResult',{}).fetch('AvailableFacets',{})
			available_facets.each do |available_facet|
				if available_facet["Id"] == facet_provided_id || facet_provided_id == "all"
					facet_label = available_facet["Label"]
					facet_id = available_facet["Id"]
					facet_values = []
					available_facet["AvailableFacetValues"].each do |available_facet_value|
						facet_value = available_facet_value["Value"]
						facet_count = available_facet_value["Count"]
						facet_action = available_facet_value["AddAction"]
						facet_values.push({value: facet_value, hitcount: facet_count, action: facet_action})
					end
					facets_hash.push(id: facet_id, label: facet_label, values: facet_values)
				end
			end
			return facets_hash
		end

		def date_range
			mindate = @results["SearchResult"]["AvailableCriteria"]["DateRange"]["MinDate"]
			maxdate = @results["SearchResult"]["AvailableCriteria"]["DateRange"]["MaxDate"]
			minyear = mindate[0..3]
			maxyear = maxdate[0..3]
			return {mindate: mindate, maxdate: maxdate, minyear:minyear, maxyear:maxyear}
		end

		def did_you_mean
			dym_suggestions = @results.fetch('SearchResult', {}).fetch('AutoSuggestedTerms',{})
		  dym_suggestions.each do |term|
				return term
			end
			return nil
		end

	end

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
			req = Net::HTTP::Post.new(uri.request_uri)
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

			Net::HTTP.start(uri.hostname, uri.port, :read_timeout => 10) { |http|
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
		def search(options, session_token = @session_token, auth_token = @auth_token, format = :xml)

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
