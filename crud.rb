#!/usr/bin/env ruby

require 'ftools'

def log(str)
#	STDERR.puts "[crud] #{str}"
end

def find_files(path)
	log("Scanning #{path}")
	files = []
	Dir.foreach(path) do |file|
		if file =~ /\.h$/
			files.push File.join(path,file)
		elsif File.directory?(File.join(path,file)) and not file =~ /^\./
			files.push find_files(File.join(path,file))
		end
	end
	return files.flatten
end

def process(file)
	log("Processing #{file}")
	structs = {}
	struct = nil
	methods = {}
	sname = nil

	in_struct = false
	
	IO.foreach(file) do |line|
		if line.strip =~ /^\/\//
			# comment
		elsif line =~ /^([a-zA-Z0-9_ ]+ )+(\*)?([a-z0-9A-Z_]+)\((.*)\);$/
			match = $~.to_a
			match.shift
			type = match[1].nil? ? match[0] : [match[0],match[1]].flatten
			name = match[2]
			args = match[3].split(",").map { |x| x.strip }
			methods[name] = [[type].flatten,[args].flatten]
		elsif line =~ /^typedef struct/
			if not struct.nil?
				structs[sname] = [struct,methods]
				methods = {}
			end
			struct = {}
			in_struct = true
		elsif in_struct
			if line =~ /^\{/
				# start
			elsif line =~ /^\} ([a-zA-Z0-9_]+);/
				in_struct = false;
				sname = $1
			elsif line.strip.length > 0
				tokens = line.strip.split(" ");
				tokens[tokens.size-1] = tokens[tokens.size-1][0,tokens[tokens.size-1].size-1]
				if tokens[tokens.size-1][0].chr == '*'
					last = tokens.pop
					ptr_str = ""
					(0..last.count("*")-1).each { |i| ptr_str += "*" }
					tokens.push ptr_str
					tokens.push last.gsub("*","")
				end
				struct[tokens.pop] = tokens
			end
		end
	end
	
	structs[sname] = [struct,methods]
	
	return structs
end

def generate_html(name,struct,methods)
	str = ""
		str +=  "<div class='struct'>\n"
		str +=  " <h1>#{name}"
		str +=  " <div class='footer'>&nbsp;</div></h1>\n"
		str +=  " <div class='variables'>\n"
		struct.each_pair do |id,type|
			str +=  "  <div class='variable'>\n"
			type.each_with_index do |t,i|
				if @classes.keys.include?(t)
					type[i] = "<a href='#{@classes[t]}'>#{t}</a>"
				end
			end
			str +=  "   <span class='id'>#{id}</span> <span class='type'>#{type.join(' ')}</span>\n"
			str +=  "  </div>\n"
		end
		str +=  "   <div class='footer'>&nbsp;</div>\n"
		str +=  " </div>\n"
		str +=  " <div class='methods'>\n"
		methods.each_pair do |name,signature|
			str +=  "  <div class='method'>\n"
			signature[0].each_with_index do |t,i|
				if @classes.keys.include?(t.strip)
					signature[0][i] = "<a href='#{@classes[t.strip]}'>#{t.strip}</a> "
				end
			end
			str +=  "   <span class='type'>#{signature[0].join(' ').strip}</span>\n"
			str +=  "   <span class='name'>#{name}</span>\n"
			args = signature[1].join(', ').strip
			@classes.sort.each do |klass,html|
				args.gsub!(html,"__#{html.upcase}__")
				args.gsub!(klass,"<a href='#{html}'>#{klass}</a>")
				args.gsub!("__#{html.upcase}__",html)
			end
			str +=  "   <span class='args'>(#{args})</span>\n"
			str +=  "   <div class='footer'>&nbsp;</div>\n"
			str +=  "  </div>\n"
		end
		str +=  " </div>\n"
		str +=  "</div>\n"
	return str
end

def render_file(path,objects)
	log("Rendering #{path}")
	file = path.split("/").pop
	fout = File.open(path,"w")
	fout.puts <<HTM
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"	"http://www.w3.org/TR/html4/strict.dtd">

<html>
<head>
 <title>#{file}</title>
 <link rel="stylesheet" media="screen" type="text/css" href="default.css" />
</head>
<body>
 <div class="content">
  <div class="header">#{file.gsub('html','h')}</div>
#{@sidebar}
HTM
	objects.each_pair do |name,pair|
		fout.puts generate_html(name,*pair) if not pair[0].nil?
	end
	fout.puts "</div></body></html>"
	fout.close
end

def make_index(path)
	html = <<HTM
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"	"http://www.w3.org/TR/html4/strict.dtd">

<html>
<head>
 <title>#{$1}</title>
 <link rel="stylesheet" media="screen" type="text/css" href="default.css" />
</head>
<body>
 <div class="content">
HTM
	html += @sidebar
	html += <<HTM
 </div>
</body>
</html>
HTM
	fout = File.open(path,"w")
	fout.puts html
	fout.close	
end

def make_sidebar
	@sidebar = <<HTM
 <div class="navigation">
  <ul class="classes">
HTM
	@classes.sort { |a,b| a[0].downcase <=> b[0].downcase }.each do |klass,url|
		@sidebar += <<HTM
   <li><a href="#{url}">#{klass}</a></li>
HTM
	end
	@sidebar += <<HTM
  </ul>
 </div>
HTM
	return @sidebar
end

#########################################
if __FILE__ == $0
#########################################

dir = ARGV[0].nil? ? "." : ARGV[0]

files = find_files(dir).map { |f| [f,process(f)] }

classes = files.map { |x| [x[0],x[1].keys] }.reject { |x| x[1][0].nil? }
@classes = {}
classes.each do |pair|
	pair[0] =~ /([^.\/]+)\.h$/
	pair[1].each do |klass|
		@classes[klass] = "#{$1}.html"
	end
end

make_sidebar

if not File.exists?("doc")
	Dir.mkdir("doc")
	css = File.join(ENV['HOME'],".crud","default.css")
	File.copy(css,"doc")
end

make_index(File.join("doc","index.html"))

files.each do |pair|
	pair[0] =~ /([^.\/]+)\.h$/
	render_file(File.join("doc","#{$1}.html"),pair[1])
end

STDERR.puts "Documented #{@classes.size} classes in #{files.size} files"
		
#########################################
end
#########################################
