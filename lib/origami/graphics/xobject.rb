=begin

= File
	graphics/xobject.rb

= Info
	This file is part of Origami, PDF manipulation framework for Ruby
	Copyright (C) 2010	Guillaume Delugré <guillaume AT security-labs DOT org>
	All right reserved.
	
  Origami is free software: you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Origami is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public License
  along with Origami.  If not, see <http://www.gnu.org/licenses/>.

=end

module Origami

  #
  # A class representing a Stream containing the contents of a Page.
  #
  class ContentStream < Stream
    
    DEFAULT_SIZE = 12
    DEFAULT_FONT = :F1
    DEFAULT_LEADING = 20
    DEFAULT_STROKE_COLOR = Graphics::Color::GrayScale.new(0.0)
    DEFAULT_FILL_COLOR = Graphics::Color::GrayScale.new(1.0)
    DEFAULT_LINECAP = Graphics::LineCapStyle::BUTT_CAP
    DEFAULT_LINEJOIN = Graphics::LineJoinStyle::MITER_JOIN
    DEFAULT_DASHPATTERN = Graphics::DashPattern.new([], 0)
    DEFAULT_LINEWIDTH = 1.0

    attr_reader :instructions
    attr_accessor :canvas
    
    def initialize(rawdata = "", dictionary = {})
    
      @instructions = nil
      @canvas = Graphics::DummyCanvas.new

      super(rawdata, dictionary)
    end

    def render(engine)
      load! if @instructions.nil?

      @instructions.each do |instruction|
        instruction.render(engine)
      end

      nil
    end

    def pre_build #:nodoc:
      load! if @instructions.nil?
      if @canvas.gs.text_state.is_in_text_object?
        @instructions << PDF::Instruction.new('ET').render(@canvas)
      end

      @data = @instructions.join
      
      super
    end

    def instructions
      load! if @instructions.nil?

      @instructions
    end

    def draw_image(name, attr = {})
      load! if @instructions.nil?

      x, y = attr[:x], attr[:y]

      @instructions << PDF::Instruction.new('q')
      @instructions << PDF::Instruction.new('cm', 300, 0, 0, 300, x, y)
      @instructions << PDF::Instruction.new('Do', name)
      @instructions << PDF::Instruction.new('Q')
    end

    #
    # Draw a straight line from the point at coord _from_, to the point at coord _to_.
    #
    def draw_line(from, to, attr = {})
      draw_polygon([from, to], attr)
    end

    #
    # Draw a polygon from a array of coordinates.
    #
    def draw_polygon(coords = [], attr = {})
      load! if @instructions.nil?

      stroke_color  = attr[:stroke_color] || DEFAULT_STROKE_COLOR
      fill_color    = attr[:fill_color] || DEFAULT_FILL_COLOR
      line_cap      = attr[:line_cap] || DEFAULT_LINECAP
      line_join     = attr[:line_join] || DEFAULT_LINEJOIN
      line_width    = attr[:line_width] || DEFAULT_LINEWIDTH
      dash_pattern  = attr[:dash] || DEFAULT_DASHPATTERN

      stroke        = attr[:stroke].nil? ? true : attr[:stroke]
      fill          = attr[:fill].nil? ? false : attr[:fill]

      stroke = true if fill == false and stroke == false 

      set_fill_color(fill_color) if fill
      set_stroke_color(stroke_color) if stroke
      set_line_width(line_width)
      set_line_cap(line_cap)
      set_line_join(line_join)
      set_dash_pattern(dash_pattern)
   
      if @canvas.gs.text_state.is_in_text_object?
        @instructions << PDF::Instruction.new('ET').render(@canvas)
      end

      unless coords.size < 1
        x,y = coords.slice!(0)
        @instructions << PDF::Instruction.new('m',x,y).render(@canvas)

        coords.each do |px,py|
          @instructions << PDF::Instruction.new('l',px,py).render(@canvas)
        end

        @instructions << (i =
          if stroke and not fill
            PDF::Instruction.new('s')
          elsif fill and not stroke
            PDF::Instruction.new('f')
          elsif fill and stroke
            PDF::Instruction.new('b')
          end
        )

        i.render(@canvas)
      end

      self
    end

    #
    # Draw a rectangle at position (_x_,_y_) with defined _width_ and _height_.
    #
    def draw_rectangle(x, y, width, height, attr = {})
      load! if @instructions.nil?

      stroke_color  = attr[:stroke_color] || DEFAULT_STROKE_COLOR
      fill_color    = attr[:fill_color] || DEFAULT_FILL_COLOR
      line_cap      = attr[:line_cap] || DEFAULT_LINECAP
      line_join     = attr[:line_join] || DEFAULT_LINEJOIN
      line_width    = attr[:line_width] || DEFAULT_LINEWIDTH
      dash_pattern  = attr[:dash] || DEFAULT_DASHPATTERN

      stroke        = attr[:stroke].nil? ? true : attr[:stroke]
      fill          = attr[:fill].nil? ? false : attr[:fill]

      stroke = true if fill == false and stroke == false 

      set_fill_color(fill_color) if fill
      set_stroke_color(stroke_color) if stroke
      set_line_width(line_width)
      set_line_cap(line_cap)
      set_line_join(line_join)
      set_dash_pattern(dash_pattern)

      if @canvas.gs.text_state.is_in_text_object?
        @instructions << PDF::Instruction.new('ET').render(@canvas)
      end

      @instructions << PDF::Instruction.new('re', x,y,width,height).render(@canvas)
  
      @instructions << (i =
        if stroke and not fill
          PDF::Instruction.new('S')
        elsif fill and not stroke
          PDF::Instruction.new('f')
        elsif fill and stroke
          PDF::Instruction.new('B')
        end
      )

      i.render(@canvas)
      
      self
    end

    #
    # Adds text to the content stream with custom formatting attributes.
    # _text_:: Text to write.
    # _attr_:: Formatting attributes.
    #
    def write(text, attr = {})
      load! if @instructions.nil?

      x,y       = attr[:x], attr[:y] 
      font      = attr[:font] || DEFAULT_FONT
      size      = attr[:size] || DEFAULT_SIZE
      leading   = attr[:leading] || DEFAULT_LEADING
      color     = attr[:color] || attr[:fill_color] || DEFAULT_STROKE_COLOR
      stroke_color = attr[:stroke_color] || DEFAULT_STROKE_COLOR
      line_width    = attr[:line_width] || DEFAULT_LINEWIDTH
      word_spacing  = attr[:word_spacing]
      char_spacing  = attr[:char_spacing]
      scale     = attr[:scale]
      rise      = attr[:rise]
      rendering = attr[:rendering]

      @instructions << PDF::Instruction.new('ET').render(@canvas) if (x or y) and @canvas.gs.text_state.is_in_text_object?

      unless @canvas.gs.text_state.is_in_text_object? 
        @instructions << PDF::Instruction.new('BT').render(@canvas)
      end

      set_text_font(font, size)
      set_text_pos(x, y) if x or y
      set_text_leading(leading) if leading
      set_text_rendering(rendering) if rendering
      set_text_rise(rise) if rise
      set_text_scale(scale) if scale
      set_text_word_spacing(word_spacing) if word_spacing
      set_text_char_spacing(char_spacing) if char_spacing
      set_fill_color(color)
      set_stroke_color(stroke_color) 
      set_line_width(line_width)

      write_text_block(text)
     
      self
    end

    def paint_shading(shade)
      load! if @instructions.nil?
      @instructions << PDF::Instruction.new('sh', shade).render(@canvas)

      self
    end

    def set_text_font(fontname, size)
      load! if @instructions.nil?
      if fontname != @canvas.gs.text_state.font or size != @canvas.gs.text_state.font_size
        @instructions << PDF::Instruction.new('Tf', fontname, size).render(@canvas)
      end

      self
    end

    def set_text_pos(tx,ty)
      load! if @instructions.nil?
      @instructions << PDF::Instruction.new('Td', tx, ty).render(@canvas)
      
      self
    end

    def set_text_leading(leading)
      load! if @instructions.nil?
      if leading != @canvas.gs.text_state.leading
        @instructions << PDF::Instruction.new('TL', leading).render(@canvas)
      end

      self
    end

    def set_text_rendering(rendering)
      load! if @instructions.nil?
      if rendering != @canvas.gs.text_state.rendering_mode
        @instructions << PDF::Instruction.new('Tr', rendering).render(@canvas)
      end

      self
    end

    def set_text_rise(rise)
      load! if @instructions.nil?
      if rise != @canvas.gs.text_state.text_rise
        @instructions << PDF::Instruction.new('Ts', rise).render(@canvas)
      end
      
      self
    end

    def set_text_scale(scaling)
      load! if @instructions.nil?
      if scale != @canvas.gs.text_state.scaling
        @instructions << PDF::Instruction.new('Tz', scaling).render(@canvas)
      end

      self
    end

    def set_text_word_spacing(word_spacing)
      load! if @instructions.nil?
      if word_spacing != @canvas.gs.text_state.word_spacing
        @instructions << PDF::Instruction.new('Tw', word_spacing).render(@canvas)
      end
      
      self
    end

    def set_text_char_spacing(char_spacing)
      load! if @instructions.nil?
      if char_spacing != @canvas.gs.text_state.char_spacing
        @instructions << PDF::Instruction.new('Tc', char_spacing).render(@canvas)
      end

      self
    end

    def set_fill_color(color)
      load! if @instructions.nil?
      
      @instructions << ( i =
        if (color.respond_to? :r and color.respond_to? :g and color.respond_to? :b) or (color.is_a?(::Array) and color.size == 3)
          r = (color.respond_to?(:r) ? color.r : color[0]).to_f / 255
          g = (color.respond_to?(:g) ? color.g : color[1]).to_f / 255
          b = (color.respond_to?(:b) ? color.b : color[2]).to_f / 255
          PDF::Instruction.new('rg', r, g, b) if @canvas.gs.nonstroking_color != [r,g,b]

        elsif (color.respond_to? :c and color.respond_to? :m and color.respond_to? :y and color.respond_to? :k) or (color.is_a?(::Array) and color.size == 4)
          c = (color.respond_to?(:c) ? color.c : color[0]).to_f
          m = (color.respond_to?(:m) ? color.m : color[1]).to_f
          y = (color.respond_to?(:y) ? color.y : color[2]).to_f
          k = (color.respond_to?(:k) ? color.k : color[3]).to_f
          PDF::Instruction.new('k', c, m, y, k) if @canvas.gs.nonstroking_color != [c,m,y,k]
          
        elsif color.respond_to?:g or (0.0..1.0) === color 
          g = color.respond_to?(:g) ? color.g : color
          PDF::Instruction.new('g', g) if @canvas.gs.nonstroking_color != [ g ]

        else
          raise TypeError, "Invalid color : #{color}"
        end
      )

      i.render(@canvas) if i
      self 
    end
    
    def set_stroke_color(color)
      load! if @instructions.nil?
      
      @instructions << ( i =
        if (color.respond_to? :r and color.respond_to? :g and color.respond_to? :b) or (color.is_a?(::Array) and color.size == 3)
          r = (color.respond_to?(:r) ? color.r : color[0]).to_f / 255
          g = (color.respond_to?(:g) ? color.g : color[1]).to_f / 255
          b = (color.respond_to?(:b) ? color.b : color[2]).to_f / 255
          PDF::Instruction.new('RG', r, g, b) if @canvas.gs.stroking_color != [r,g,b]

        elsif (color.respond_to? :c and color.respond_to? :m and color.respond_to? :y and color.respond_to? :k) or (color.is_a?(::Array) and color.size == 4)
          c = (color.respond_to?(:c) ? color.c : color[0]).to_f
          m = (color.respond_to?(:m) ? color.m : color[1]).to_f
          y = (color.respond_to?(:y) ? color.y : color[2]).to_f
          k = (color.respond_to?(:k) ? color.k : color[3]).to_f
          PDF::Instruction.new('K', c, m, y, k) if @canvas.gs.stroking_color != [c,m,y,k]
          
        elsif color.respond_to?:g or (0.0..1.0) === color 
          g = color.respond_to?(:g) ? color.g : color
          PDF::Instruction.new('G', g) if @canvas.gs.stroking_color != [ g ]

        else
          raise TypeError, "Invalid color : #{color}"
        end
      )

      i.render(@canvas) if i
      self 
    end

    def set_dash_pattern(pattern)
      load! if @instructions.nil?
      unless @canvas.gs.dash_pattern.eql? pattern
        @instructions << PDF::Instruction.new('d', pattern.array, pattern.phase).render(@canvas)
      end

      self
    end

    def set_line_width(width)
      load! if @instructions.nil?
      if @canvas.gs.line_width != width
        @instructions << PDF::Instruction.new('w', width).render(@canvas)
      end

      self
    end

    def set_line_cap(cap)
      load! if @instructions.nil?
      if @canvas.gs.line_cap != cap
        @instructions << PDF::Instruction.new('J', cap).render(@canvas)
      end

      self
    end
    
    def set_line_join(join)
      load! if @instructions.nil?
      if @canvas.gs.line_join != join
        @instructions << PDF::Instruction.new('j', join).render(@canvas)
      end

      self
    end

    private

    def load!
      decode!

      code = StringScanner.new self.data
      @instructions = []
      
      until code.eos?
        insn = PDF::Instruction.parse(code)
        @instructions << insn if insn
      end
      
      self
    end

    def write_text_block(text)
      
      lines = text.split("\n").map!{|line| line.to_s}
      
      @instructions << PDF::Instruction.new('Tj', lines.slice!(0)).render(@canvas)
      lines.each do |line|
        @instructions << PDF::Instruction.new("'", line).render(@canvas)
      end
      
    end
    
  end #class ContentStream

  module Graphics

    module XObject
      def self.included(receiver)
        receiver.field  :Type,    :Type => Name, :Default => :XObject
      end
    end

    class FormXObject < ContentStream
      include XObject
      include ResourcesHolder

      field   :Subtype,       :Type => Name, :Default => :Form, :Required => true
      field   :FormType,      :Type => Integer, :Default => 1
      field   :BBox,          :Type => Array, :Required => true
      field   :Matrix,        :Type => Array, :Default => [1, 0, 0, 1, 0, 0]
      field   :Resources,     :Type => Resources, :Version => "1.2"
      field   :Group,         :Type => Dictionary, :Version => "1.4"
      field   :Ref,           :Type => Dictionary, :Version => "1.4"
      field   :Metadata,      :Type => Stream, :Version => "1.4"
      field   :PieceInfo,     :Type => Dictionary, :Version => "1.3"
      field   :LastModified,  :Type => String, :Version => "1.3"
      field   :StructParent,  :Type => Integer, :Version => "1.3"
      field   :StructParents, :Type => Integer, :Version => "1.3"
      field   :OPI,           :Type => Dictionary, :Version => "1.2"
      field   :OC,            :Type => Dictionary, :Version => "1.5"
      field   :Name,          :Type => Name
      field   :Measure,       :Type => Dictionary, :Version => "1.7", :ExtensionLevel => 3
      field   :PtData,        :Type => Dictionary, :Version => "1.7", :ExtensionLevel => 3

      def pre_build
        self.Resources = Resources.new.pre_build unless has_field?(:Resources)

        super
      end

    end

    class ImageXObject < Stream
      include XObject

      field   :Subtype,           :Type => Name, :Default => :Image, :Required => true
      field   :Width,             :Type => Integer, :Required => true
      field   :Height,            :Type => Integer, :Required => true
      field   :ColorSpace,        :Type => [ Name, Array ]
      field   :BitsPerComponent,  :Type => Integer
      field   :Intent,            :Type => Name, :Version => "1.1"
      field   :ImageMask,         :Type => Boolean, :Default => false
      field   :Mask,              :Type => [ Stream, Array ], :Version => "1.3"
      field   :Decode,            :Type => Array
      field   :Interpolate,       :Type => Boolean, :Default => false
      field   :Alternates,        :Type => Array, :Version => "1.3"
      field   :SMask,             :Type => Stream, :Version => "1.4"
      field   :SMaskInData,       :Type => Integer, :Default => 0, :Version => "1.5"
      field   :Name,              :Type => Name
      field   :StructParent,      :Type => Integer, :Version => "1.3"
      field   :ID,                :Type => String, :Version => "1.3"
      field   :OPI,               :Type => Dictionary, :Version => "1.2"
      field   :Metadata,          :Type => Stream, :Version => "1.4"
      field   :OC,                :Type => Dictionary, :Version => "1.5"
      field   :Measure,           :Type => Dictionary, :Version => "1.7", :ExtensionLevel => 3
      field   :PtData,            :Type => Dictionary, :Version => "1.7", :ExtensionLevel => 3

      def self.from_image_file(path, format = nil)

        if path.respond_to?(:read)
          fd = path
        else
          fd = File.open(File.expand_path(path), 'r').binmode
          format ||= File.extname(path) 
          format.slice!(0) if format and format[0,1] == '.'
        end
     
        if ''.respond_to? :force_encoding
          data = fd.read.force_encoding('binary') # 1.9
        else
          data = fd.read
        end

        fd.close

        image = ImageXObject.new

        raise ArgumentError, "Missing file format" if format.nil?
        case format.downcase
          when 'jpg', 'jpeg', 'jpe', 'jif', 'jfif', 'jfi'
            image.setFilter :DCTDecode    
            image.rawdata = data

            image

          when 'jp2','jpx','j2k','jpf','jpm','mj2'
            image.setFilter :JPXDecode
            image.rawdata = data
            
            image

          when 'jb2', 'jbig', 'jbig2'
            image.setFilter :JBIG2Decode
            image.rawdata = data

            image
        else
          raise NotImplementedError, "Unknown file format: '#{format}'"
        end
      end

      #
      # Converts an ImageXObject stream into an image file data.
      # Output format depends on the stream encoding: 
      #   * JPEG for DCTDecode
      #   * JPEG2000 for JPXDecode
      #   * JBIG2 for JBIG2Decode
      #   * PNG for everything else
      #
      #   Returns an array of the form [ _format_, _data_ ]
      #
      def to_image_file
        encoding = self.Filter
        encoding = encoding[0] if encoding.is_a? ::Array

        case (encoding && encoding.value)
          when :DCTDecode then [ 'jpg', self.data ]
          when :JBIG2Decode then [ 'jbig2', self.data ]
          when :JPXDecode then [ 'jp2', self.data ]

        else
          raise InvalidColorError, "No colorspace specified" unless self.ColorSpace

          case cs = self.ColorSpace.value
            when Color::Space::DEVICE_GRAY
              colortype = 0
              components = 1
            when Color::Space::DEVICE_RGB
              colortype = 2
              components = 3
            when ::Array
              cstype = cs[0].is_a?(Reference) ? cs[0].solve : cs[0]
              case cstype.value
                when :Indexed
                  colortype = 3
                  components = 3
                  csbase = cs[1].is_a?(Reference) ? cs[1].solve : cs[1]
                  lookup = cs[3].is_a?(Reference) ? cs[3].solve : cs[3]

                when :ICCBased
                  iccprofile = cs[1].is_a?(Reference) ? cs[1].solve : cs[1]
                  raise InvalidColorError, 
                    "Invalid ICC Profile parameter" unless iccprofile.is_a?(Stream)
                  
                  case iccprofile.N
                    when 1
                      colortype = 0
                      components = 1
                    when 3
                      colortype = 2
                      components = 3
                  else
                    raise InvalidColorError,
                      "Invalid number of components in ICC profile: #{iccprofile.N}"
                  end
              else
                raise InvalidColorError, "Unsupported color space: #{self.ColorSpace}"
              end
          else
            raise InvalidColorError, "Unsupported color space: #{self.ColorSpace}"
          end

          bpc = self.BitsPerComponent || 8
          w,h = self.Width, self.Height
          pixels = self.data
          
          hdr = [137, 80, 78, 71, 13, 10, 26, 10].pack('C*')
          chunks = []

          chunks <<
          [
            'IHDR',
            [
              w, h,
              bpc, colortype, 0, 0, 0
            ].pack("N2C5")
          ]


          if self.Intents
            intents =
              case self.Intents.value
                when Intents::PERCEPTUAL then 0
                when Intents::RELATIVE then 1
                when Intents::SATURATION then 2
                when Intents::ABSOLUTE then 3
              else
                3
              end

            chunks <<
            [
              'sRGB',
              [ intents ].pack('C')
            ]

            chunks << [ 'gAMA', [ 45455 ].pack("N") ]
            chunks << 
            [ 
              'cHRM', 
              [ 
                31270,
                32900,
                64000,
                33000,
                30000,
                60000,
                15000,
                6000
              ].pack("N8") 
            ]
          end

          if colortype == 3
            lookup =
              case lookup
                when Stream then lookup.data
                when String then lookup.value
              else 
                raise InvalidColorError, "Invalid indexed palette table"
              end

            raise InvalidColorError, "Invalid base color space" unless csbase
            palette = ""

            case csbase.value
              when Color::Space::DEVICE_GRAY
                lookup.each_byte do |g|
                  palette << Color.gray_to_rgb(g).pack("C3")
                end              
              when Color::Space::DEVICE_RGB
                palette << lookup[0, (lookup.size / 3) * 3]
              when Color::Space::DEVICE_CMYK
                (lookup.size / 4).times do |i|
                  cmyk = lookup[i * 4, 4].unpack("C4").map!{|c| c.to_f / 255}
                  palette << Color.cmyk_to_rgb(*cmyk).map!{|c| (c * 255).to_i}.pack("C3")
                end
              when ::Array
                case csbase[0].solve.value
                  when :ICCBased
                    iccprofile = csbase[1].solve
                    raise InvalidColorError, 
                      "Invalid ICC Profile parameter" unless iccprofile.is_a?(Stream)
                    
                    case iccprofile.N
                      when 1
                        lookup.each_byte do |g|
                          palette << Color.gray_to_rgb(g).pack("C3")
                        end
                      when 3
                        palette << lookup[0, (lookup.size / 3) * 3]
                    else
                      raise InvalidColorError,
                        "Invalid number of components in ICC profile: #{iccprofile.N}"
                    end
                else
                  raise InvalidColorError, "Unsupported color space: #{csbase}"
                end
            else
              raise InvalidColorError, "Unsupported color space: #{csbase}"
            end

            if iccprofile
              chunks <<
              [
                'iCCP',
                'ICC Profile' + "\x00\x00" + Zlib::Deflate.deflate(iccprofile.data, Zlib::BEST_COMPRESSION)
              ]
            end

            chunks <<
            [
              'PLTE',
              palette
            ]

            bpr = w
          else

            if iccprofile
              chunks <<
              [
                'iCCP',
                'ICC Profile' + "\x00\x00" + Zlib::Deflate.deflate(iccprofile.data, Zlib::BEST_COMPRESSION)
              ]
            end

            bpr = (bpc >> 3) * components * w
          end

          require 'zlib'
           
          nrows = pixels.size / bpr
          nrows.times do |irow|
            pixels.insert(irow * bpr + irow, "\x00")
          end
          
          chunks <<
          [
            'IDAT',
             Zlib::Deflate.deflate(pixels, Zlib::BEST_COMPRESSION)
          ]

          if self.Metadata.is_a?(Stream)
            chunks <<
            [
              'tEXt',
              "XML:com.adobe.xmp" + "\x00" + self.Metadata.data
            ]
          end

          chunks << [ 'IEND', '' ]
  
          [ 'png', 
            hdr + chunks.map!{ |chk|
              [ chk[1].size, chk[0], chk[1], Zlib.crc32(chk[0] + chk[1]) ].pack("NA4A*N")
            }.join
          ]
        end
      end
    end

    class ReferenceDictionary < Dictionary
      include StandardObject

      field   :F,             :Type => Dictionary, :Required => true
      field   :Page,          :Type => [Integer, String], :Required => true
      field   :ID,            :Tyoe => Array
    end

  end

end

