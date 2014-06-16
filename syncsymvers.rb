require 'optparse'
require 'bindata'

options = {}
oldhashes = {}

class ModSum < BinData::Record
  endian :little
  uint32 :sum
  string :name, :read_length => 60
end


OptionParser.new do |opts|
	opts.banner = "Usage: syncsymvers.rb --f[ile] <file.ko> --r[ef] <refernce.ko>"
	opts.on("-f", "--file FILE", String, "Input file that will be modified") do |v|
		options[:file] = v
	end
	opts.on("-r", "--ref FILE", String, "Input file that has needed modversion checksums") do |v|
		options[:ref] = v
	end
end.parse!


if options.has_key?(:ref) == false or options.has_key?(:file) == false then
	puts "Type syncsymvers.rb --help to see usage!"
	exit
end

offset_org = 0 # 0x6BD1C
offset_ref = 0 # 0x6F2A8

File.open(options[:ref], 'rb') do |f|
	puts "Looking for signature of reference file..."
	while not f.eof? do
		if f.read(4) == "modu" and f.read(4) == "le_l" \
		and f.read(4) == "ayou" then
			offset_ref = f.pos - 16
			puts "Found module_layout @ 0x#{offset_ref.to_s(16)}"
			break
		end
	end
	
	if f.eof? then
		puts "ERROR: Signature not found!"
		exit
	end
	f.rewind
	
	f.seek(offset_ref, IO::SEEK_CUR) 
	while not f.eof? do
		data = ModSum.read(f)
		break if data.sum < 1000
		oldhashes[data.name] = data.sum
	end
	if f.eof? then
		puts "ERROR: Reached end of file!"
		exit
	end
end

File.open(options[:file], 'rb+') do |f|
	puts "Looking for signature of original file..."
	while not f.eof? do
		if f.read(4) == "modu" and f.read(4) == "le_l" \
		and f.read(4) == "ayou" then
			offset_org = f.pos - 16
			puts "Found module_layout @ 0x#{offset_org.to_s(16)}"
			break
		end
	end
	
	if f.eof? then
		puts "ERROR: Signature not found!"
		exit
	end
	
	f.rewind
	f.seek(offset_org, IO::SEEK_CUR) 
	while not f.eof? do
		data = ModSum.read(f)
		break if data.sum < 1000
		#puts "TEST: #{data.name}: #{data.sum} => #{oldhashes[data.name]}\n" 
		if oldhashes.has_key?(data.name) and oldhashes[data.name] != data.sum then
			f.seek(-64, IO::SEEK_CUR)
			puts "#{data.name}: #{data.sum} => #{oldhashes[data.name]}"
			BinData::Uint32le.new(oldhashes[data.name]).write(f)
			f.seek(60, IO::SEEK_CUR)
		end
	end
end
puts "OK"
1
