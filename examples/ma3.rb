# frozen_string_literal: true

require 'scrapework'

# The archive web page
class Archive < Scrapework::Object
  ROOT = 'http://www.ma3comic.com/strips-ma3/'

  has_many :pages

  def self.load(*)
    super(ROOT + 'archive/')
  end

  map :pages do |html|
    html.css('select[name=comic] option').drop(1).map.with_index do |page, i|
      { url: ROOT + page['value'], number: i + 1 }
    end
  end
end

# The page web page
class Page < Scrapework::Object
  attribute :src
  attribute :number, type: Integer

  map :src do |html|
    img(html)['src']
  end

  map :number do |html|
    img(html)['title'].slice(/\d+/).to_i
  end

  def filename
    "#{number.to_s.rjust(3, '0')}.png"
  end

  def img(html)
    html.css('img#cc-comic').first
  end
end

require 'open-uri'

archive = Archive.load

Dir.mkdir('ma3') unless Dir.exist?('ma3')
Dir.chdir('ma3') do
  archive.pages.each_slice(20) do |pages|
    threads = []
    pages.each do |page|
      next if File.exist?(page.filename)

      threads << Thread.new(page) do |this_page|
        begin
          this_page.load
        rescue StandardError => e
          puts "error (#{this_page.url}): #{e.message}"
          retry
        end

        uri = URI.parse(this_page.src)
        File.write(this_page.filename, uri.read)
      end
    end
    threads.each(&:join)
  end
end
