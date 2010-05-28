require 'mimemagic_tables'
require 'stringio'

# Mime type detection
class MimeMagic
  VERSION = '0.1.2'

  attr_reader :type, :mediatype, :subtype

  # Mime type by type string
  def initialize(type)
    @type      = type
    @mediatype = @type.split('/')[0]
    @subtype   = @type.split('/')[1]
  end

  # Add custom mime type. Arguments:
  # * <i>type</i>: Mime type
  # * <i>extensions</i>: String list of file extensions
  # * <i>parents</i>: String list of parent mime types
  # * <i>magics</i>: Mime magic specification array
  def self.add(type, extensions, parents, *magics)
    TYPES[type] = [extensions, parents, magics]
    extensions.each do |ext|
      EXTENSIONS[ext] = type
    end
    MAGIC.unshift [type, magics] if magics
  end

  # Returns true if type is a text format
  def text?
    child_of? 'text/plain'
  end

  # Returns true if type is image
  def image?
    mediatype == 'image'
  end

  # Mediatype shortcuts
  def image?; mediatype == 'image'; end
  def audio?; mediatype == 'audio'; end
  def video?; mediatype == 'video'; end

  # Returns true if type is child of parent type
  def child_of?(parent)
    child?(type, parent)
  end

  # Get string list of file extensions
  def extensions
    TYPES.key?(type) ? TYPES[type][0] : []
  end

  # Lookup mime type by file extension
  def self.by_extension(ext)
    ext = ext.downcase
    mime = EXTENSIONS[ext] || (ext[0..0] == '.' && EXTENSIONS[ext[1..-1]])
    mime ? new(mime) : nil
  end

  # Lookup mime type by magic content analysis.
  # This is a slow operation.
  def self.by_magic(io)
    if !(io.respond_to?(:seek) && io.respond_to?(:read))
      io = io.to_s
      io.force_encoding('ascii-8bit') if io.respond_to?(:force_encoding)
      io = StringIO.new(io, 'rb')
    end
    mime = MAGIC.find {|type, matches| magic_match(io, matches) }
    mime ? new(mime[0]) : nil
  end

  # Return type as string
  def to_s
    type
  end

  # Allow comparison with string
  def ==(x)
    type == x.to_s
  end

  private

  def child?(child, parent)
    child == parent || TYPES.key?(child) && TYPES[child][1].any? {|p| child?(p, parent) }
  end

  def self.magic_match(io, matches)
    matches.any? do |offset, value, children|
      match = if Range === offset
		io.seek(offset.begin)
                io.read(offset.end - offset.begin + value.length).include?(value)
              else
                io.seek(offset)
		value == io.read(value.length)
              end
      match && (!children || magic_match(io, children))
    end
  rescue
    false
  end

  private_class_method :magic_match
end