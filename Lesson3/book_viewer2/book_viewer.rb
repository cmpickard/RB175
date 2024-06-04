require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

def search_chapters(query, chapter_list)
  matching_chapters = chapter_list.select.with_index do |chapter_name,idx|
    ch_text = File.read("data/chp#{idx+1}.txt")
    ch_text.match?(/#{query}/i)
  end
  
  find_matching_paragraphs(matching_chapters, query)
end

def find_matching_paragraphs(matching_chapters, query)
  matching_chapters.map do |chapter_name|
    paragraph_arr = []
    ch_num = get_ch_num(chapter_name, @contents)
    paragraphs = in_paragraphs(File.read("data/chp#{ch_num}.txt")).split("</p>")
    
    paragraphs.each_with_index do |paragraph, id|
      paragraph.gsub!(/(#{query})/, "<strong>\\1</strong>" )
      paragraph_arr << [paragraph, id] if paragraph.match?(/#{query}/)
    end
    {chapter_name => paragraph_arr}
  end
end

def get_ch_num(chapter, chapter_list)
  (chapter_list.index(chapter) + 1).to_s
end

before do
  @contents = File.read("data/toc.txt").split("\n")
end

helpers do
  def in_paragraphs(text)
    para_text = ("<p>" + text + "</p>").gsub(/\n\n/,"</p><p>")
    para_text.count("<p>").times do |num|
      para_text.sub!(/\<p\>/, "<p id=\"paragraph-#{num}\">")
    end
    para_text
  end

  def get_paragraph(chapter_title, id)
    num = get_ch_num(chapter_title, @contents)
    text = in_paragraphs(File.read("data/chp#{num}.txt"))
    match = text.scan(/id="paragraph-#{id}">.{60}/)
  end
end

not_found do
  redirect "/"
end

get "/search" do
  @query = params["query"]
  @matches = search_chapters(@query, @contents) unless @query.nil?
  erb :search
  # @matches.to_s
end

get "/" do
  @title = "The Adventures of Sherlock Holmes"
  erb :home
end

get "/chapters/:number" do
  @chapter_num = params["number"]
  redirect "/" unless (1..@contents.size).cover?(@chapter_num.to_i)

  @chapter_text = File.read("data/chp#{@chapter_num}.txt")
  @title = @contents[@chapter_num.to_i - 1]
  erb :chapter
end
