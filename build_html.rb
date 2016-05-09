#!/usr/bin/env ruby

require 'pp'
require 'kramdown'

def walk(path, &process_file)
  Dir.foreach(path) do |file|
    new_path = File.join(path, file)
    if file == '.' or file == '..'
      next
    elsif File.directory?(new_path)
      walk(new_path, &process_file)
    elsif file =~ /.*\.md/
      yield(path, file)
    end
  end
end

def create_dir(path)
  parts = path.split('/')
  parts.each_with_index do |part, i|
    parts_path = parts[0..i].join('/')
    (Dir.mkdir parts_path) rescue Errno::EEXIST
  end
end

def render_path(*path_parts)
  path = path_parts.map do |part|
    if part.length <= 1
      nil
    elsif part[-1] == '/'
      part
    else
      "#{part}/"
    end
  end
  path.join
end

def render_partial(partial_name)
  "\n{::nomarkdown}\n" + File.read(File.join(Dir.pwd, "layouts/_#{partial_name}.html")) + "{:/}\n"
end

def transform(html)
  block_pattern = /{{([^}]*)}}/

  if block_line = html[block_pattern, 1]
    block_it = block_line.strip.split
    action   = block_it.shift

    if block_it.count > 1
      id_part = block_it.join('__').downcase
    else
      id_part = block_it.first.downcase
    end

    case action
    when 'BEGIN'
      case id_part
      when 'questionnaire-iframe'
        html.sub! block_pattern, render_partial('questionnaire')
      when 'navigation',
           'counter',
           'home__specialised-services',
           'home__traffic-management',
           'home__zero-rating'
        html.sub! block_pattern, "<div class=\"#{id_part}\">"
      when 'home__video', 'home__newsletter'
        html.sub! block_pattern, "
          <div class=\"#{id_part}__outer\">
          <div class=\"#{id_part}__inner\">
          <div class=\"#{id_part}__content\">
        " + render_partial(id_part.split('__').last)
      else
        html.sub! block_pattern, "
          <div class=\"#{id_part}__outer\">
          <div class=\"#{id_part}__inner\">
          <div class=\"#{id_part}__content\">
        "
      end
    when 'END'
      case id_part
      when 'questionnaire-iframe'
        html.sub! block_pattern, ''
      when 'navigation',
           'counter',
           'home__specialised-services',
           'home__traffic-management',
           'home__zero-rating'
        html.sub! block_pattern, '</div>'
      else
        html.sub! block_pattern, '
          </div>
          </div>
          </div>
        '
      end
    when 'ANCHOR'
      html.sub! block_pattern, "\n<span id=\"#{id_part}\"></span>\n"
    when 'LOGOS'
      case id_part
      when 'made-by'
        html.sub! block_pattern, render_partial('made-by')
      when 'supported-by'
        html.sub! block_pattern, render_partial('supported-by')
      end
    end
    transform html
  else
    html.gsub /^ */, ''
  end
end

def build_site(language, description)
  build_path   = render_path "build",   description, language
  content_path = render_path "content", description, language

  walk(content_path) do |path, content_file_name|
    relative_path = render_path path.split('/')[3..-1].join('/')
    target_path   = render_path build_path, relative_path

    layout_path = File.join(render_path("layouts"), "site.html.erb")
    target_file_name = content_file_name.split('.')[0..-2].push('html').join('.')

    # create html from kramdown flavoured markdown
    content_kramdown = transform File.read(File.join(path, content_file_name))
    puts content_kramdown
    document = Kramdown::Document.new(content_kramdown, template: layout_path, parse_block_html: true, auto_ids: false)

    # write html
    create_dir target_path
    target_file = File.new File.join(target_path, target_file_name), 'w'
    target_file << document.to_html
  end
end

def build_all
  Dir.foreach('content') do |site|
    site_path = File.join('content', site)
    next if site == '.' or site == '..' or not File.directory?(site_path)
    Dir.foreach(site_path) do |language|
      language_path = File.join(site_path, language)
      next if language == '.' or language == '..' or not File.directory?(language_path)
      # Process.fork {
        build_site language, site
      # }
    end
  end
end

build_all

# TODO: trigger build via travis on git master push