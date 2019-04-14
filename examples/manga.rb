# frozen_string_literal: true

require 'scrapework'

# This example sets up several data types and uses them
# to download every chapter of a manga.

# A manga web page
class Manga < Scrapework::Object
  attribute :title

  has_many :chapters

  map :title do |html|
    html.css('h1.entry-title').text.strip
  end

  map :chapters do |html|
    html.css('.chapter-list .row a').reverse.map.with_index do |chapter, i|
      { url: chapter['href'], title: chapter['title'], number: i + 1 }
    end
  end
end

# A manga chapter web page
class Chapter < Scrapework::Object
  attribute :title
  attribute :number, type: Integer

  belongs_to :manga
  has_many :pages

  map :title do |html|
    html.css('h1.entity-title').text.strip
  end

  map :manga do |html|
    manga = html.css('.breadcrumbs_doc p span:nth-child(3) a').first
    { url: manga['href'], title: manga.text.strip }
  end

  map :pages do |html|
    html.css('.vung_doc img').map.with_index do |page, i|
      url = page['src']
      ext = File.extname(url)
      padded_number = i.to_s.rjust(3, '0')
      padded_chapter = number.to_s.rjust(3, '0')
      filename = "#{manga.title} #{padded_chapter}-#{padded_number}#{ext}"

      { url: url, filename: filename, number: i + 1 }
    end
  end
end

# A manga page image
class Page < Scrapework::Object
  attribute :filename
  attribute :number, type: Integer

  belongs_to :chapter
end

require 'open-uri'

manga = Manga.load('https://mangabat.com/manga/serie-1088909590')

Dir.mkdir(manga.title) unless Dir.exist?(manga.title)
Dir.chdir(manga.title) do
  manga.chapters.each do |chapter|
    Dir.mkdir(chapter.title) unless Dir.exist?(chapter.title)
    Dir.chdir(chapter.title) do
      chapter.pages.each do |page|
        next if File.exist?(page.filename)

        File.open(page.filename, 'w') do |f|
          uri = URI.parse(page.url)
          f.write(uri.read)
        end
      end
    end
  end
end
