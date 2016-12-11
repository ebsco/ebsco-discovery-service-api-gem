require 'net/http'
require 'cgi'
require 'json'
require 'openssl'

#TO DO: Finish publication Exact Match object - probably needs to be a subclass of EDSAPIRecord
#TO DO: Finish Detailed Records

module EDSApi

	API_URL = "http://eds-api.ebscohost.com/"
	API_URL_S = "https://eds-api.ebscohost.com/"

	DB_LABEL_LOOKUP = {}
	DB_LABEL_LOOKUP["EDB"] = "Publisher Provided Full Text Searching File"
	DB_LABEL_LOOKUP["EDO"] = "Supplemental Index"
	DB_LABEL_LOOKUP["ASX"] = "Academic Search Index"
	DB_LABEL_LOOKUP["A9H"] = "Academic Search Complete"
	DB_LABEL_LOOKUP["APH"] = "Academic Search Premier"
	DB_LABEL_LOOKUP["AFH"] = "Academic Search Elite"
	DB_LABEL_LOOKUP["A2H"] = "Academic Search Alumni Edition"
	DB_LABEL_LOOKUP["ASM"] = "Academic Search Main Edition"
	DB_LABEL_LOOKUP["ASR"] = "STM Source"
	DB_LABEL_LOOKUP["BSX"] = "Business Source Index"
	DB_LABEL_LOOKUP["EDSEBK"] = "Discovery eBooks"
	DB_LABEL_LOOKUP["VTH"] = "Art & Architecture Complete"
	DB_LABEL_LOOKUP["IIH"] = "Computers & Applied Sciences Complete"
	DB_LABEL_LOOKUP["CMH"] = "Consumer Health Complete - CHC Platform"
	DB_LABEL_LOOKUP["C9H"] = "Consumer Health Complete - EBSCOhost"
	DB_LABEL_LOOKUP["EOAH"] = "E-Journals Database"
	DB_LABEL_LOOKUP["EHH"] = "Education Research Complete"
	DB_LABEL_LOOKUP["HCH"] = "Health Source: Nursing/Academic"
	DB_LABEL_LOOKUP["HXH"] = "Health Source: Consumer Edition"
	DB_LABEL_LOOKUP["HLH"] = "Humanities International Complete"
	DB_LABEL_LOOKUP["LGH"] = "Legal Collection"
	DB_LABEL_LOOKUP["SLH"] = "Sociological Collection"
	DB_LABEL_LOOKUP["CPH"] = "Computer Source"
	DB_LABEL_LOOKUP["PBH"] = "Psychology & Behavioral Sciences Collection"
	DB_LABEL_LOOKUP["RLH"] = "Religion & Philosophy Collection"
	DB_LABEL_LOOKUP["NFH"] = "Newspaper Source"
	DB_LABEL_LOOKUP["N5H"] = "Newspaper Source Plus"
	DB_LABEL_LOOKUP["BWH"] = "Regional Business News"
	DB_LABEL_LOOKUP["OFM"] = "OmniFile Full Text Mega"
	DB_LABEL_LOOKUP["RSS"] = "Rehabilitation & Sports Medicine Source"
	DB_LABEL_LOOKUP["SYH"] = "Science & Technology Collection"
	DB_LABEL_LOOKUP["SCF"] = "Science Full Text Select"
	DB_LABEL_LOOKUP["HEH"] = "Health Business Elite"

	class EDSAPIRecord

		attr_accessor :record

		def initialize(results_record)
			@record = results_record;
		end

		def resultid
			@record["ResultId"]
		end

		def an
			@record["Header"]["An"].to_s
		end

		def dbid
			@record["Header"]["DbId"].to_s
		end

		def plink
			@record["Header"]["PLink"]
		end

		def score
			@record["Header"]["RelevancyScore"]
		end

		def pubtype
			@record["Header"]["PubType"]
		end

		def pubtype_id
			@record["Header"]["PubTypeId"]
		end

		def db_label
			if DB_LABEL_LOOKUP.key?(self.dbid.upcase)
				dblabel = DB_LABEL_LOOKUP[self.dbid.upcase];
			else
				dblabel = @record["Header"]["DbLabel"]
			end
		end

		def images (size_requested = "all")
			returned_images = []

			images = @record.fetch('ImageInfo', {})
			if images.count > 0
				images.each do |image|
					if size_requested == image["Size"] || size_requested == "all"
						returned_images.push({size: image["Size"], src: image["Target"]})
					end
				end
			end
			return returned_images
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

			return nil
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
			return nil
		end
		#end title_raw

		def authors

			items = @record.fetch('Items',{})
			if items.count > 0
				items.each do |item|
					if item["Group"] == "Au"
						return item["Data"]
					end
				end
			end

			contributors = @record.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibRelationships', {}).fetch('HasContributorRelationships', {})

			if contributors.count > 0
				authors = []
				contributors.each do |contributor|
					names = contributor.fetch('PersonEntity',{})
					authors.push(names['Name']['NameFull'])
				end
				author_str = authors.join("; ")
				return author_str
			end

			return nil
		end

		def authors_raw

			contributors = @record.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibRelationships', {}).fetch('HasContributorRelationships', {})

			if contributors.count > 0
				authors = []
				contributors.each do |contributor|
					names = contributor.fetch('PersonEntity',{})
					authors.push(names['Name']['NameFull'])
				end
				return authors
			end

			items = @record.fetch('Items',{})
			if items.count > 0
				items.each do |item|
					if item["Group"] == "Au"
						return [item["Data"]]
					end
				end
			end

			return []
		end


		def subjects

			items = @record.fetch('Items',{})
			if items.count > 0
				items.each do |item|
					if item["Group"] == "Su"
						return item["Data"]
					end
				end
			end

			subjects = @record.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibEntity', {}).fetch('Subjects', {})

			if subjects.count > 0
				subs = []
				subjects.each do |subject|
					subs.push(subject["SubjectFull"])
				end
				subs_str = subs.join("; ")
				return subs_str
			end

			return nil
		end

		def subjects_raw

			subjects = @record.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibEntity', {}).fetch('Subjects', {})

			if subjects.count > 0
				subs = []
				subjects.each do |subject|
					subs.push(subject)
				end
				return subs
			end

			items = @record.fetch('Items',{})
			if items.count > 0
				items.each do |item|
					if item["Group"] == "Su"
						return [item["Data"]]
					end
				end
			end

			return []
		end

		def languages
			language_section = @record.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibEntity', {}).fetch('Languages', {})

			if language_section.count > 0
				langs = []
				language_section.each do |language|
					langs.push(language["Text"])
				end
				return langs
			end
			return []
		end

		def pages
			pagination_section = @record.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibEntity', {}).fetch('PhysicalDescription', {})

			if pagination_section.count > 0
				return pagination_section["Pagination"]
			end
			return {}
		end

		def abstract
			items = @record.fetch('Items',{})
			if items.count > 0
				items.each do |item|
					if item["Group"] == "Ab"
						return item["Data"]
					end
				end
			end

			return nil
		end

		def html_fulltext
			htmlfulltextcheck = @record.fetch('FullText',{}).fetch('Text',{}).fetch('Availability',0)
			if htmlfulltextcheck == "1"
				return @record.fetch('FullText',{}).fetch('Text',{})["Value"]
			end
			return nil
		end

		def source

			items = @record.fetch('Items',{})
			if items.count > 0
				items.each do |item|
					if item["Group"] == "Src"
						return item["Data"]
					end
				end
			end

			return nil
		end

		def source_title

			unless self.source.nil?
				ispartof = @record.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibRelationships', {}).fetch('IsPartOfRelationships', {})

				if ispartof.count > 0
					ispartof.each do |contributor|
						titles = contributor.fetch('BibEntity',{}).fetch('Titles',{})
						titles.each do |title_src|
							if title_src["Type"] == "main"
								return title_src["TitleFull"]
							end
						end
					end
				end
			end
			return nil

		end

		def numbering
			ispartof = @record.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibRelationships', {}).fetch('IsPartOfRelationships', {})

			if ispartof.count > 0
				numbering = []
				ispartof.each do |contributor|
					nums = contributor.fetch('BibEntity',{}).fetch('Numbering',{})
					nums.each do |num|
						numbering.push(num)
					end
				end
				return numbering
			end

			return []
		end

		def doi
			ispartof = @record.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibEntity', {}).fetch('Identifiers', {})

			if ispartof.count > 0
				ispartof.each do |ids|
					if ids["Type"] == "doi"
						return ids["Value"]
					end
				end
			end

			return nil
		end

		def isbns

			ispartof = @record.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibRelationships', {}).fetch('IsPartOfRelationships', {})

			if ispartof.count > 0
				issns = []
				ispartof.each do |part_of|
					ids = part_of.fetch('BibEntity',{}).fetch('Identifiers',{})
					ids.each do |id|
						if id["Type"].include?("isbn") && !id["Type"].include?("locals")
							issns.push(id)
						end
					end
				end
				return issns
			end
			return []
		end

		def issns

			ispartof = @record.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibRelationships', {}).fetch('IsPartOfRelationships', {})

			if ispartof.count > 0
				issns = []
				ispartof.each do |part_of|
					ids = part_of.fetch('BibEntity',{}).fetch('Identifiers',{})
					ids.each do |id|
						if id["Type"].include?("issn") && !id["Type"].include?("locals")
							issns.push(id)
						end
					end
				end
				return issns
			end
			return []
	  end

		def source_isbn
		  unless self.source.nil?

				ispartof = @record.fetch('RecordInfo', {}).fetch('BibRecord', {}).fetch('BibRelationships', {}).fetch('IsPartOfRelationships', {})

				if ispartof.count > 0
					issns = []
					ispartof.each do |part_of|
						ids = part_of.fetch('BibEntity',{}).fetch('Identifiers',{})
						ids.each do |id|
							if id["Type"].include?("isbn") && !id["Type"].include?("locals")
								issns.push(id)
							end
						end
					end
					return issns
				end
		  end
			return []
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

		def retrieve_options
			options = {}
			options['an'] = self.an
			options['dbid'] = self.dbid
			return options
		end

	end

	## SEARCH RESPONSE PARSING

	class EDSAPIResponse

		attr_accessor :results, :records, :dblabel, :researchstarters, :publicationmatch, :debug

		def initialize(search_results)
			@debug = ""
			@results = search_results

			unless @results['ErrorNumber'].nil?
				return search_results
			end

			if self.hitcount > 0
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
		end

		def hitcount
			@results["SearchResult"]["Statistics"]["TotalHits"]
		end

		def searchtime
			@results["SearchResult"]["Statistics"]["TotalSearchTime"]
		end

		def querystring
			@results["SearchRequestGet"]["QueryString"]
		end

		def current_search
			CGI::parse(self.querystring)
		end

		def applied_facets

			af = []

			applied_facets_section = @results["SearchRequestGet"].fetch('SearchCriteriaWithActions',{}).fetch('FacetFiltersWithAction',{})
			applied_facets_section.each do |applied_facets|
				applied_facets.fetch('FacetValuesWithAction',{}).each do |applied_facet|
					af.push(applied_facet)
#					unless applied_facet['FacetValuesWithAction'].nil?
#						applied_facet_values = applied_facet.fetch('FacetValuesWithAction',{})
#						applied_facet_values.each do |applied_facet_value|
#							af.push(applied_facet_value)
#						end
#					end
				end
			end

			return af
		end

		def applied_limiters

			af = []

			applied_limters_section = @results["SearchRequestGet"].fetch('SearchCriteriaWithActions',{}).fetch('LimitersWithAction',{})
			applied_limters_section.each do |applied_limter|
				af.push(applied_limter)
			end

			return af
		end

		def applied_expanders

			af = []

			applied_expanders_section = @results["SearchRequestGet"].fetch('SearchCriteriaWithActions',{}).fetch('ExpandersWithAction',{})
			applied_expanders_section.each do |applied_explander|
				af.push(applied_explander)
			end

			return af
		end

		def database_stats
			databases = []
			databases_facet = @results["SearchResult"]["Statistics"]["Databases"]
			databases_facet.each do |database|
				if DB_LABEL_LOOKUP.key?(database["Id"].upcase)
					db_label = DB_LABEL_LOOKUP[database["Id"].upcase];
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

		def searchterms
			queries = @results.fetch('SearchRequestGet',{}).fetch('SearchCriteriaWithActions',{}).fetch('QueriesWithAction',{})

			terms = []
			queries.each do |query|
				query['Query']['Term'].split.each do |word|
					terms.push(word)
				end
			end

			return terms
		end

	end

	class EDSAPIInfo

		attr_accessor :info

		def initialize(info_raw)
			@info = info_raw
		end

		def sorts (id = "all")
			possible_sorts = []
			available_sorts = @info['AvailableSearchCriteria'].fetch('AvailableSorts',{})
			available_sorts.each do |available_sort|
				if available_sort["Id"] == id || id == "all"
					possible_sorts.push(available_sort)
				end
			end
			return possible_sorts
		end

		def search_fields (id = "all")
			possible_fields = []
			available_fields = @info['AvailableSearchCriteria'].fetch('AvailableSearchFields',{})
			available_fields.each do |available_field|
				if available_field['FieldCode'] == id || id == "all"
					possible_fields.push(available_field)
				end
			end
			return possible_fields
		end

		def expanders (id = "all")
			possible_expanders = []
			available_expanders = @info['AvailableSearchCriteria'].fetch('AvailableExpanders',{})
			available_expanders.each do |available_expander|
				if available_expander['Id'] == id || id == "all"
					possible_expanders.push(available_expander)
				end
			end
			return possible_expanders
		end

		def limiters (id = "all")
			possible_limiters = []
			available_limiters = @info['AvailableSearchCriteria'].fetch('AvailableLimiters',{})
			available_limiters.each do |available_limiter|
				if available_limiter['Id'] == id || id == "all"
					possible_limiters.push(available_limiter)
				end
			end
			return possible_limiters
		end

		def search_modes (id = "all")
			possible_search_modes = []
			available_search_modes = @info['AvailableSearchCriteria'].fetch('AvailableSearchModes',{})
			available_search_modes.each do |available_search_mode|
				if available_search_mode['Mode'] == id || id == "all"
					possible_search_modes.push(available_search_mode)
				end
			end
			return possible_search_modes
		end

		def related_content (id = "all")
			possible_related_contents = []
			available_related_contents = @info['AvailableSearchCriteria'].fetch('AvailableRelatedContent',{})
			available_related_contents.each do |available_related_content|
				if available_related_content['Type'] == id || id == "all"
					possible_related_contents.push(available_related_content)
				end
			end
			return possible_related_contents
		end

		def did_you_mean (id = "all")
			possible_dyms = []
			available_dyms = @info['AvailableSearchCriteria'].fetch('AvailableDidYouMeanOptions',{})
			available_dyms.each do |available_dym|
				if available_dym['Id'] == id || id == "all"
					possible_dyms.push(available_dym)
				end
			end
			return possible_dyms
		end

		def results_per_page
			return @info['ViewResultSettings']['ResultsPerPage']
		end

		def results_list_view
			return @info['ViewResultSettings']['ResultListView']
		end

		def default_options
			options = {}
			self.search_modes.each do |search_mode|
				if search_mode['DefaultOn'] == "y"
					options['searchmode'] = [search_mode['Mode']]
				end
			end

			options['resultsperpage'] = [self.results_per_page]
			options['sort'] = ['relevance']
			options['view'] = [self.results_list_view]

			default_limiters = []
			self.limiters.each do |limiter|
				if limiter['Type'] == 'select' && limiter['DefaultOn'] == 'y'
					default_limiters.push(limiter['Id']+":"+'y')
				elsif limiter['Type'] == 'multiselectvalue'
					limiter['LimiterValues'].each do |limiter_value|
						unless limiter_value['DefaultOn'].nil?
							default_limiters.push(limiter['Id']+":"+limiter_value['Value'])
						end
					end
				end
			end
			if default_limiters.count > 0
				options['limiter'] = default_limiters
			end

			default_expanders = []
			self.expanders.each do |expander|
				if expander['DefaultOn'] == 'y'
					default_expanders.push(expander['Id'])
				end
			end
			if default_expanders.count > 0
				options['expander'] = default_expanders
			end

			default_relatedcontent = []
			self.related_content.each do |related_info|
				if related_info['DefaultOn'] == 'y'
					default_relatedcontent.push(related_info['Type'])
				end
			end
			if default_relatedcontent.count > 0
				options['relatedcontent'] = [default_relatedcontent.join(",")]
			end

			return options
		end

	end

  ## CONNECTION HANDLING

	# Connection object. Does what it says. ConnectionHandler is what is usually desired and wraps auto-reonnect features, etc.
	class Connection

	  attr_accessor :auth_token, :session_token, :guest
	  attr_writer :userid, :password

		def initialize
			@log = ""
		end

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
    def request_search(options, format = :xml)
			uri = URI "#{API_URL}edsapi/rest/Search?#{options}"
			@log << uri.to_s << " -- "
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
		def request_retrieve(dbid, an, highlightterms = "", ebookpreferredformat = "", format = :xml)
			uri = URI "#{API_URL}edsapi/rest/retrieve?dbid=#{dbid}&an=#{an}"
			@log << uri.to_s << " -- "

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
		def request_info(format = :xml)
			uri = URI "#{API_URL}edsapi/rest/Info"
			@log << uri.to_s << " -- "

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

		def show_log
			return @log
		end
	end

	# Handles connections - retries failed connections, passes commands along
	class ConnectionHandler < Connection

		attr_accessor :max_retries
		attr_accessor :session_token
		attr_accessor :info
		attr_accessor :search_results

		def initialize(max_retries = 2)
			@max_retries = max_retries
			super()
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
				@info = EDSApi::EDSAPIInfo.new(self.request_info(@session_token,@auth_token))
		  	return result['SessionToken']
		  end
		end

		def new_search(searchterm, use_defaults = "y")
			options = @info.default_options
			options['query'] = searchterm
			return self.search(options)
		end

		def search(options, actions = [])
			if actions.kind_of?(Array) && actions.count > 0
				options['action'] = actions
			elsif actions.length > 0
				options['action'] = [actions]
			end
			apiresponse = EDSApi::EDSAPIResponse.new(request_search(URI.encode_www_form(options)))
			@current_searchterms = apiresponse.searchterms
			@search_results = apiresponse
			return apiresponse
		end

		def search_actions(actions)
			return self.search(@search_results.current_search,actions)
		end

		def retrieve(options)
			options['highlightterms'] = @current_searchterms
			options['ebookpreferredformat'] = 'ebook-epub'
			apiresponse = request_retrieve(options['dbid'],options['an'],options['hhighlightterms'])
			unless apiresponse["Record"].nil?
				return EDSApi::EDSAPIRecord.new(apiresponse["Record"])
			end
			return apiresponse
		end

		def request_search(options, session_token = @session_token, auth_token = @auth_token, format = :xml)

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

		def request_info (session_token, auth_token, format= :xml)
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

		def request_retrieve(dbid, an, highlightterms, ebookpreferredformat = 'ebook-epub', session_token = @session_token, auth_token = @auth_token, format = :xml)
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
