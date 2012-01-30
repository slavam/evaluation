module ApplicationHelper
def title(page_title, options={})
  content_for(:title, page_title.to_s)
  return content_tag(:h1, page_title, options)
end

def page_title
  (@content_for_title + " &mdash; " if @content_for_title).to_s + 'My Cool Site'
end

def page_heading(text)
  content_tag(:h1, content_for(:title){ text })
end


end
