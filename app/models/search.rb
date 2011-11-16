class Search
  include Mongoid::Document

  # Fields
  field :occasion, :type => Time
  field :maxpage, :type => Integer
  field :games, :type => Array

  # Validation

  # Scopes

  # Helpers
  def self::inspect_page page
    # Add any new matches on this page
    url     = 'http://stats.espncricinfo.com/ci/engine/stats/index.json?class=11;page=%s;template=results;type=aggregate;view=results' % page
    doc     = get_data(url)
    nodeset = doc.xpath('//a[text()="Match scorecard"]')

    if nodeset.length == 0
      return false # page not found
    else
      nodeset.each do |node|
        match_href  = node.attributes['href'].value
        match_id    = match_href.split('/').last.split('.').first
        match       = Match.find_or_create_by(match_id: match_id)
      end

      return true # page found
    end
  end

  def self::new_matches
    # What was the last page we found last time?
    lastpage = Integer(Settings.get(:lastpage))
    lastpage ||= 1

    # Inspect this & subsequent pages
    loop do
      break unless inspect_page lastpage
      lastpage += 1
    end

    lastpage -= 1 # The last page we looked for was the one that didn't exist

    # Wrap up
    Settings.set(:lastpage, lastpage)
  end
end
