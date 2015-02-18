require 'net/http'
require 'uri'
require 'cgi'
require 'nokogiri'
require 'csv'
require 'json'


# The search page is a post request with form data:
#   intsearchby - This will be 4 for searching by business category.
#   BUSCODE - The code for the business category.  Those are in a file called 'business_category_codes.txt'
#   intSearchOpt - This will be 2 but don't know why...
COC_SEARCH_URL = "http://members.columbiamochamber.com/sbaweb/members/advancedsearch.asp"
BUSINESS_CODES_FILENAME = "business_category_codes.txt"
BUSINESS_CSV_FILENAME = "businesses.csv"

# CSS classes (The tabs show HTML structure).
BUSINESS_CONTAINER_CLASS = "sbaMemberBorderShadow"
  BUSINESS_NAME_CLASS = "sbaMemberName"
  BUSINESS_MAIN_CONTACT_CLASS = "sbaMainContact"
  BUSINESS_ADDRESS_CLASS = "sbaDispAddr"
    # Has a <br> to separate address
  BUSINESS_PHONE_CLASS = "sbaDispPhone"
  BUSINESS_CATEGORY_CLASS = "sbaBuscDescBottom"
    # Contains an anchor that has the category
  BUSINESS_LINK_MENU_CLASS = "sbaLinkMenu"
    # This will contain the link to the website.


# Must update cookies as a work around to Chamber of Commerce's attempts to prevent web scraping. Located under Network tab in Chrome.
COOKIES = "ASPSESSIONIDQQSTSSDB=JPJLGBKBPEAACMHGHGALODDF; __utmt=1; sbaweb=wpid=%2D101&id=6093&hdr=&cookies=true; ASPSESSIONIDQQSTSSDB=JPJLGBKBPEAACMHGHGALODDF; __utma=47718587.1095979035.1424226626.1424226626.1424226626.1; __utmb=47718587.23.10.1424226626; __utmc=47718587; __utmz=47718587.1424226626.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)"

POST_HEADERS = {
  "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
  "Accept-Encoding" => "gzip,deflate",
  "Accept-Language" => "en-US,en;q=0.8",
  "Cache-Control" => "max-age=0",
  "Connection" => "keep-alive",
  "Content-Length" => "41",
  "Content-Type" => "application/x-www-form-urlencoded",
  "Cookie" => COOKIES,
  "Host" => "members.columbiamochamber.com",
  "Origin" => "http://members.columbiamochamber.com",
  "Referer" => "http://members.columbiamochamber.com/sbaweb/members/advancedsearch.asp",
  "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/38.0.2125.104 Safari/537.36"
}

GET_HEADERS = {
  "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
  "Accept-Encoding" => "gzip,deflate,sdch",
  "Accept-Language" => "en-US,en;q=0.8",
  "Cache-Control" => "max-age=0",
  "Connection" => "keep-alive",
  "Cookie" => COOKIES,
  "Host" => "members.columbiamochamber.com",
  "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/38.0.2125.104 Safari/537.36"
}

def main

    businesses = []

    bus_codes = business_category_codes()
    bus_codes.each_with_index do |bus_code, i|
      resp = get_POST_reponse(COC_SEARCH_URL, {
        intsearchby: 4,
        BUSCODE: bus_code,
        intSearchOpt: 2
      })

      puts "Business Code: #{bus_code} [#{i + 1} of #{bus_codes.count}]..."

      links = get_additional_links_on_page(resp)
        businesses = businesses + get_businesses_from_page(resp)

        if links
          links.each_with_index do |link, i|
            puts "Page #{i + 2}..."
            get_resp = get_GET_reponse(link)
            businesses = businesses + get_businesses_from_page(get_resp)
          end
        end
      puts "Total Businesses: #{businesses.count}"


      output = File.open( "outputfile.json","w" )
      begin
        output << businesses.to_json
      rescue => e
        puts e
      ensure
        output.close
      end
    end
  # CSV.open(File.join(File.dirname(__FILE__), BUSINESS_CSV_FILENAME), "wb", { force_quotes: true }) do |csv|
  #   csv << [
  #     "Name",
  #     "Main Contact",
  #     "Address",
  #     "Phone",
  #     "Category",
  #     "Has Website"
  #   ]
  #
  #   businesses.each do |business|
  #     csv << [
  #       business[:name],
  #       business[:contact],
  #       business[:address],
  #       business[:phone],
  #       business[:category],
  #       business[:has_website]
  #     ]
  #   end
  # end
end

def get_additional_links_on_page(resp_body)
  # Get links on the page that aren't the first
  links = []
  doc = Nokogiri::HTML(resp_body)

  link_anchor_container = doc.css("p.sbasmall").first
  if link_anchor_container.nil?
    return nil
  end

  link_anchors = link_anchor_container.css("a.body")
  if link_anchors.nil?
    return nil
  end

  link_anchors.each do |link|
    links << link["href"]
  end

  return links
end

def get_businesses_from_page(resp_body)
  businesses = []
  doc = Nokogiri::HTML(resp_body)
  doc.css(".#{BUSINESS_CONTAINER_CLASS}").each do |bus_container|

    begin
      bus_name = CGI.unescapeHTML(bus_container.css(".#{BUSINESS_NAME_CLASS}").first.xpath("text()").to_s.force_encoding("ISO-8859-1").encode("UTF-8"))
      bus_main_contact = CGI.unescapeHTML(bus_container.css(".#{BUSINESS_MAIN_CONTACT_CLASS}").first.xpath("text()").to_s.force_encoding("ISO-8859-1").encode("UTF-8"))
      bus_address = CGI.unescapeHTML(bus_container.css(".#{BUSINESS_ADDRESS_CLASS}").first.inner_html.force_encoding("ISO-8859-1").encode("UTF-8").gsub!("<br>", ", "))
      bus_phone = CGI.unescapeHTML(bus_container.css(".#{BUSINESS_PHONE_CLASS}").first.xpath("text()").to_s.force_encoding("ISO-8859-1").encode("UTF-8").gsub("Phone: ", ""))
      bus_category = CGI.unescapeHTML(bus_container.css(".#{BUSINESS_CATEGORY_CLASS} a").first.xpath("text()").to_s.force_encoding("ISO-8859-1").encode("UTF-8"))

      bus_has_website = false
      first_menu_link = bus_container.css(".#{BUSINESS_LINK_MENU_CLASS} a.body").first
      if first_menu_link.xpath("text()").to_s == "Web Site"
        bus_has_website = true
      end

      #puts "Business Name: #{bus_name}"
      #puts "Business Main Contact: #{bus_main_contact}"
      #puts "Business Address: #{bus_address}"
      #puts "Business Phone: #{bus_phone}"
      #puts "Business Category: #{bus_category}"
      #puts "Business Has Website: #{bus_has_website}"
      #puts

      businesses << { name: bus_name, contact: bus_main_contact, address: bus_address, phone: bus_phone, category: bus_category, has_website: bus_has_website }
    rescue => e
      puts e
      puts "An error occured when parsing a business."
    end
  end
  return businesses
end

def business_category_codes
  File.open(File.join(File.dirname(__FILE__), BUSINESS_CODES_FILENAME), "r").read.strip.split
end

def get_POST_reponse(url, form_data)
  begin
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)

    req = Net::HTTP::Post.new(url, POST_HEADERS)
    req.set_form_data(form_data)

    res = nil
    http.start do
      res = http.request(req)
    end

    if res.nil?
      return nil
    else

      # puts res.body
      return res.body
    end
  rescue => e
    puts e
  end
end

def get_GET_reponse(url)
  begin
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)

    req = Net::HTTP::Get.new(url, GET_HEADERS)

    res = nil
    http.start do
      res = http.request(req)
    end

    if res.nil?
      return nil
    else
      return res.body
    end
  rescue => e
    puts e
  end
end

if __FILE__ == $0
  puts "Yay"
  main()
end
