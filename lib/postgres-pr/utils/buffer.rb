require 'postgres-pr/utils/binary_writer'

unless "".respond_to?(:getbyte)
  class String
    alias :getbyte :[]
  end
end

module PostgresPR
  module Utils
    # Fixed size buffer.
    class Buffer

      class Error < RuntimeError; end
      class EOF < Error; end 

      def self.from_string(str)
        new(str)
      end

      def self.of_size(size)
        raise ArgumentError if size < 0
        new('#' * size)
      end 

      def initialize(content)
        @size = content.size
        @content = content
        @position = 0
      end

      def size
        @size
      end

      def position
        @position
      end

      def position=(new_pos)
        raise ArgumentError if new_pos < 0 or new_pos > @size
        @position = new_pos
      end

      def at_end?
        @position == @size
      end

      def content
        @content
      end

      def read(n)
        raise EOF, 'cannot read beyond the end of buffer' if @position + n > @size
        str = @content[@position, n]
        @position += n
        str
      end

      def write(str)
        sz = str.size
        raise EOF, 'cannot write beyond the end of buffer' if @position + sz > @size
        @content[@position, sz] = str
        @position += sz
        self
      end

      def readbyte
        raise EOF, 'cannot read beyond the end of buffer' if @position >= @size
        byte = @content.getbyte(@position)
        @position += 1
        byte
      end
      alias read_byte readbyte
      
      def read_int16_network
        raise EOF, 'cannot read beyond the end of buffer' if @position + 2 > @size
        byte1, byte2 = @content.getbyte(@position), @content.getbyte(@position + 1)
        @position += 2
        (byte1 < 128 ? byte1 : byte1 - 256) * 256 + byte2
      end

      def read_int32_network
        raise EOF, 'cannot read beyond the end of buffer' if @position + 4 > @size
        byte1, byte2 = @content.getbyte(@position), @content.getbyte(@position + 1)
        byte3, byte4 = @content.getbyte(@position + 2), @content.getbyte(@position + 3)
        @position += 4
        ((((byte1 < 128 ? byte1 : byte1 - 256) * 256 + byte2) * 256) + byte3) * 256 + byte4
      end

      def copy_from_stream(stream, n)
        raise ArgumentError if n < 0
        while n > 0
          str = stream.read(n) 
          write(str)
          n -= str.size
        end
        raise if n < 0 
      end

      NUL = "\000"

      def write_cstring(cstr)
        raise ArgumentError, "Invalid Ruby/cstring" if cstr.include?(NUL)
        write(cstr)
        write(NUL)
      end

      # returns a Ruby string without the trailing NUL character
      def read_cstring
        nul_pos = @content.index(NUL, @position)
        raise Error, "no cstring found!" unless nul_pos

        sz = nul_pos - @position
        str = @content[@position, sz]
        @position += sz + 1
        return str
      end

      # read till the end of the buffer
      def read_rest
        read(self.size-@position)
      end

      include BinaryWriterMixin
    end
  end
end
