# frozen_string_literal: true

class Search
  include Mongoid::Document

  # Fields
  field :occasion, type: DateTime
  field :maxpage, type: Integer
  field :games, type: Array

  # Validation

  # Scopes

  # Helpers
  def self.inspect_page(page)
    # Add any new matches on this page
    url = format(
      'https://stats.espncricinfo.com/ci/engine/stats/index.json?class=11;page=%<page>s;template=results;type=aggregate;view=results',
      page: page
    )
    doc     = get_data(url)
    nodeset = doc.xpath('//a[text()="Match scorecard"]')

    if nodeset.empty?
      dputs "Page #{page} has no matches", :red
      false # page not found
    else
      nodeset.each do |node|
        match_href    = node.attributes['href'].value
        match_ref     = match_href.split('/').last.split('.').first
        match         = Match.find_or_create_by! match_ref: match_ref

        match.parsed  = false if match.parsed.nil?
        match.save!

        break unless match.persisted?

        # Why not parse the match straight away?
        dputs "Failed to parse match #{match_ref}", :red if !match.parsed && !Match.parse(match_ref)

        # -dp match # debug
        @search.games << match_ref unless @search.nil?
      end

      true # page found
    end
  end

  def self.new_matches
    @search = create occasion: Time.zone.now, games: []

    # What was the last page we found last time?
    lastpage = (Settings.get(:lastpage) || 1).to_i

    # Inspect this & subsequent pages
    loop do
      dputs "Inspecting page #{lastpage}", :green
      break unless inspect_page lastpage

      Settings.set(:lastpage, lastpage)
      lastpage += 1
    end

    lastpage -= 1 # The last page we looked for was the one that didn't exist

    # Wrap up
    @search.maxpage = lastpage
    @search.save
  end
end
