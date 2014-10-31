#
# TODO
# Add if it has website to hash
# Cleanse address for concatted address and city
# Unescape HTML escape sequences
#
#
#
#
#
#
#
require 'nokogiri'
require 'uri'
require 'net/http'

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

POST_HEADERS = {
  "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
  "Accept-Encoding" => "gzip,deflate",
  "Accept-Language" => "en-US,en;q=0.8",
  "Cache-Control" => "max-age=0",
  "Connection" => "keep-alive",
  "Content-Length" => "41",
  "Content-Type" => "application/x-www-form-urlencoded",
  "Cookie" => "ASPSESSIONIDCCDQRAAA=IKGHABHADGLBJPGMMCLLHPAL; ASPSESSIONIDSSSATDCC=DAEBPGHBDKDBGOAAFHGCOACC; __utmt=1; __utma=133477404.948335745.1414623609.1414626899.1414723460.3; __utmb=133477404.1.10.1414723460; __utmc=133477404; __utmz=133477404.1414723460.3.3.utmcsr=google|utmccn=(organic)|utmcmd=organic|utmctr=(not%20provided); sbaweb=cookies=true&id=6093&wpid=%2D101; ASPSESSIONIDCCDQRAAA=IKGHABHADGLBJPGMMCLLHPAL; ASPSESSIONIDSSSATDCC=DAEBPGHBDKDBGOAAFHGCOACC; __utma=47718587.1665526488.1414623621.1414626909.1414721677.3; __utmb=47718587.4.10.1414721677; __utmc=47718587; __utmz=47718587.1414626909.2.2.utmcsr=columbiamochamber.com|utmccn=(referral)|utmcmd=referral|utmcct=/",
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
  "Cookie" => "ASPSESSIONIDCCDQRAAA=IKGHABHADGLBJPGMMCLLHPAL; ASPSESSIONIDSSSATDCC=DAEBPGHBDKDBGOAAFHGCOACC; __utma=133477404.948335745.1414623609.1414626899.1414723460.3; __utmc=133477404; __utmz=133477404.1414723460.3.3.utmcsr=google|utmccn=(organic)|utmcmd=organic|utmctr=(not%20provided); sbaweb=cookies=true&id=6093&wpid=%2D101; ASPSESSIONIDCCDQRAAA=IKGHABHADGLBJPGMMCLLHPAL; ASPSESSIONIDSSSATDCC=DAEBPGHBDKDBGOAAFHGCOACC; __utma=47718587.1665526488.1414623621.1414626909.1414721677.3; __utmc=47718587; __utmz=47718587.1414626909.2.2.utmcsr=columbiamochamber.com|utmccn=(referral)|utmcmd=referral|utmcct=/",
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

  end

  CSV.open(File.join(File.dirname(__FILE__), BUSINESS_CSV_FILENAME), "wb") do |csv|
    businesses.each do |business|
      csv << [
        business[:name],
        business[:contact],
        business[:address],
        business[:phone],
        business[:category]
      ]
      businesses << { name: bus_name, contact: bus_main_contact, address: bus_address, phone: bus_phone, category: bus_category }
    end
  end
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
      bus_name = bus_container.css(".#{BUSINESS_NAME_CLASS}").first.xpath("text()")
      bus_main_contact = bus_container.css(".#{BUSINESS_MAIN_CONTACT_CLASS}").first.xpath("text()")
      bus_address = bus_container.css(".#{BUSINESS_ADDRESS_CLASS}").first.xpath("text()")
      bus_phone = bus_container.css(".#{BUSINESS_PHONE_CLASS}").first.xpath("text()")
      bus_category = bus_container.css(".#{BUSINESS_CATEGORY_CLASS} a").first.xpath("text()")
      #puts "Business Name: #{bus_name}"
      #puts "Business Main Contact: #{bus_main_contact}"
      #puts "Business Address: #{bus_address}"
      #puts "Business Phone: #{bus_phone}"
      #puts "Business Category: #{bus_category}"
      #puts

      businesses << { name: bus_name, contact: bus_main_contact, address: bus_address, phone: bus_phone, category: bus_category }
    rescue
      puts "An error occured when parsing a business."
    end
  end
  return businesses
end

def business_category_codes
  File.open(File.join(File.dirname(__FILE__), BUSINESS_CODES_FILENAME), "r").read.strip.split
end

def get_POST_reponse(url, form_data)
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
    return res.body
  end
end

def get_GET_reponse(url)
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
end

if __FILE__ == $0
  main()
end
