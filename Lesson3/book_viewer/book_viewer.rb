require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

def search_chapters
  chapters = @contents.select.with_index do |_, idx|
    chapter_txt = File.read("data/chp#{idx + 1}.txt")
    chapter_txt.downcase =~ /\W#{@query}\W/i
  end
  chapters = chapters.map do |chapter|
    chapter_number = @contents.index(chapter) + 1
    [chapter_number, chapter]
  end
  search_paragraphs(chapters)
end

def search_paragraphs(chapters)
  results = []
  chapters.map do |chapter_num, title|
    chapter_txt = File.read("data/chp#{chapter_num}.txt")
    paragraphs = chapter_txt.split("\n\n")
    prg_numbers = []
    prg_text = []
    paragraphs.each.with_index do |prg, idx|
      if prg.match?(/#{@query}/i)
        prg.gsub!(/(#{@query})/i, "<strong>\\1</strong>")
        prg_numbers << (10000 + idx) 
        prg_text << prg
      end
    end
    results << {[chapter_num, title] => [prg_numbers, prg_text]}
  end
  results
end

helpers do
  def in_paragraphs(text)
    id_counter = 10000
    text = "<p id=\"#{id_counter}\">" + text + "</p>"
    # create substitution loop. for each loop, generate unique id for <p> element
    (text.count("\n\n")).times do |_|
      id_counter += 1
      text = text.sub(/\n\n/,"</p><p id=\"#{id_counter}\">")
    end
    text
  end
end

before do
  @contents = File.read("data/toc.txt").split("\n")
end

not_found do
  redirect "/"
end

get "/" do
  @title = 'The Adventures of Sherlock Holmes'
  erb :home
end

get "/chapters/:number" do
  @number = params["number"]
  redirect "/" if (@number.to_i > @contents.size || 
                       @number.to_i.to_s != @number)
  chapter_title = @contents[@number.to_i - 1]
  @title = "Chapter #{@number}  |  #{chapter_title}"
  @chapter = File.read("data/chp#{@number}.txt")
  erb :chapter
end

get "/search" do
  @query = params["query"]
  @found = search_chapters if @query
  # @found is an array of hashes that looks like this,
  # [{[1, "A Scandal in Bohemia"]=>[[10000, 10003, 10130], [text]},... ]

  # TO DO NEXT:
  # need to add some of the paragraph matching text to the @found array so that
  # they can be included as the anchor link text
  erb :search
  # @found.to_s
end


