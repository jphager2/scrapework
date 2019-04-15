# frozen_string_literal: true

require 'scrapework'

# Mapping for repo tab (paginated
class RepositoryTabPage < Scrapework::Object
  has_many :repositories

  map :repositories do |html|
    html.css('a[itemprop="name codeRepository"]').map do |a|
      { url: URI.join(url, a['href']), name: a.text.strip }
    end
  end

  paginate do |html|
    pages = html.css('.paginate-container .btn')

    pages.map do |page|
      { url: page['href'] } if page && page['href'].present?
    end
  end
end

# Mapping for repository
class Repository < Scrapework::Object
  attribute :name
end

page = RepositoryTabPage.new(url: 'https://github.com/jphager2?tab=repositories')

i = 0
until page.nil?
  page.load
  page.repositories.each do |repo|
    i += 1
    puts "#{i})\t#{repo.name} (#{repo.url})"
  end

  page = page.next_page
end
