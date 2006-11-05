
module ID3Lib

  #
  # This is the class of the frames in a Tag object. You can get the frame
  # ID, find out which fields the frame has and get and set them.
  #
  #   apic = tag.frame(:APIC)
  #   apic.id              #=> :APIC
  #   apic.allowed_fields  #=> [:textenc, :mimetype, :picturetype, :description, :data]
  #   apic.mimetype        #=> "image/jpeg"
  #   apic.description = "Cover image"
  #
  class Frame

    # Frame ID
    attr_reader :id
    # Array of allowed fields for frame
    attr_reader :allowed_fields

    #
    # Returns a frame object. There are two ways to create a new object, but
    # only the first one is relevant for a normal library user.
    #
    # With an ID (e.g. APIC) for _id_or_frame_, a new empty frame is
    # created. If a block is given, the object itself is yielded.
    #
    #   apic = ID3Lib::Frame.new(:APIC)
    #
    def initialize(id_or_frame)
      if id_or_frame.is_a? API::Frame
        @api_frame = id_or_frame
        info = Info.frame_num(@api_frame.get_id)
      else
        @api_frame = nil
        info = Info.frame(id_or_frame)
      end
      if not info
        raise ArgumentError, "invalid frame ID #{id_or_frame.inspect}"
      end

      @id = info[ID]
      @allowed_fields = info[FIELDS]
      @fields = {}

      if @api_frame
        read_api_frame
      end

      yield self if block_given?
    end

    #
    # Used for field accessors like text and textenc. Which accessors are
    # available depends on the frame type.
    #
    #   title = tag.frame(:title)
    #   title.allowed_fields  #=> [:textenc, :text]
    #   title.text = "Title"
    #   title.textenc  #=> 0
    #
    def method_missing(meth, *args)
      m = meth.to_s
      assignment = m.chomp!('=')
      m = m.to_sym
      if @allowed_fields.include?(m)
        if assignment
          @fields[m] = args.first
        else
          @fields[m]
        end
      else
        super
      end
    end

    #
    # Returns the value of the field _name_. Raises ArgumentError if called
    # with an invalid field name.
    #
    def field(name)
      if not @allowed_fields.include?(name)
        raise ArgumentError, "invalid field name #{name.inspect}"
      end
      @fields[name]
    end

    #
    # Set value of field _name_ to _value_. Raises ArgumentError if called
    # with an invalid field name.
    #
    def set_field(name, value)
      if not @allowed_fields.include?(name)
        raise ArgumentError, "invalid field name #{name.inspect}"
      end
      @fields[name] = value
    end

    #
    # Returns the text of the frame or '' if there is no text.
    #
    def to_s
      @fields[:text] or ''
    end

    #
    # Returns a string containing a readable representation of the frame.
    #
    #   p title_frame
    #   #<ID3Lib::Frame:TIT2 textenc=0, text="Title">
    #
    def inspect
      [ "#<#{self.class}:#{@id} ",
        @allowed_fields.map{ |f|
          "#{f}=#{@fields[f].inspect}"
        }.join(', '),
        ">" ].join
    end

    #
    # Was the frame changed since reading it? For a newly created empty
    # frame, this is always true.
    #
    def changed?
      if @fields_hashcode
        @fields_hashcode != @fields.to_a.hash
      else
        true
      end
    end

    def == other
      other.fields_equal?(@fields)
    end

    def fields_equal?(fields)
      @fields == fields
    end
    protected :fields_equal?

    def write_api_frame # :nodoc:
      return unless changed?

      unless @api_frame
        @api_frame = API::Frame.new(Info.frame(@id)[NUM])
      end

      if textenc = @fields[:textenc]
        f = @api_frame.get_field(Info.field(:textenc)[NUM])
        f.set_integer(textenc)
      end

      @fields.each do |field_id, value|
        next if field_id == :textenc
        # Ignore invalid fields.
        next unless @allowed_fields.include? field_id

        api_field = @api_frame.get_field(Info.field(field_id)[NUM])
        next unless api_field

        case Info.field_type(api_field.get_type)
        when :integer
          api_field.set_integer(value)
        when :binary
          api_field.set_binary(value)
        when :text
          if textenc and textenc > 0 and
             [:text, :description, :filename].include?(field_id)
            # Special treatment for Unicode
            api_field.set_encoding(textenc)
            api_field.set_unicode(value)
          else
            api_field.set_ascii(value)
          end
        end
      end

      @fields_hashcode = @fields.to_a.hash
      @api_frame
    end

    private

    def read_api_frame
      info = Info.frame(@id)

      @allowed_fields.each do |field_name|
        api_field = @api_frame.get_field(Info.field(field_name)[NUM])
        next unless api_field
        @fields[field_name] =
          case Info::FieldType[api_field.get_type]
          when :integer
            api_field.get_integer
          when :binary
            api_field.get_binary
          when :text
            if api_field.get_encoding > 0
              api_field.get_unicode
            else
              api_field.get_ascii
            end
          end
      end

      @fields_hashcode = @fields.to_a.hash
      @fields
    end

  end

end
