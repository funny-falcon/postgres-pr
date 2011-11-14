require 'postgres-pr/utils/byteorder'

module PostgresPR
  module Utils
    # This mixin solely depends on method read(n), which must be defined
    # in the class/module where you mixin this module.
    module BinaryReaderMixin

      # == 8 bit

      # no byteorder for 8 bit! 

      def read_word8
        readbyte
      end

      def read_int8
        (r = readbyte) >= 128 ? r - 256 : r
      end

      alias read_byte read_word8
      
      # == 16 bit

      # === Unsigned
      
      if ByteOrder.little_endian?
        def read_word16_native
          read_word16_little
        end
      else
        def read_word16_native
          read_word16_big
        end
      end

      def read_word16_little
        fst = readbyte
        scd = readbyte
        scd * 256 + fst
      end

      def read_word16_big
        fst = readbyte
        scd = readbyte
        fst * 256 + scd
      end

      # === Signed

      def read_int16_native
        ru(2, 's')
      end

      def read_int16_little
        # swap bytes if native=big (but we want little)
        ru_swap(2, 's', ByteOrder::Big)
      end

      def read_int16_big
        # swap bytes if native=little (but we want big)
        read_int8 * 256 + read_word8
      end

      # == 32 bit

      # === Unsigned

      def read_word32_native
        ru(4, 'L')
      end

      def read_word32_little
        ru(4, 'V')
      end

      def read_word32_big
        (((read_word8 * 256) + read_word8) * 256 + read_word8) * 256 + read_word8
      end

      # === Signed

      def read_int32_native
        ru(4, 'l')
      end

      def read_int32_little
        # swap bytes if native=big (but we want little)
        ru_swap(4, 'l', ByteOrder::Big) 
      end

      def read_int32_big
        (((read_int8 * 256) + read_word8) * 256 + read_word8) * 256 + read_word8
      end

      # == Aliases

      alias read_uint8 read_word8

      # add some short-cut functions 
      %w(word16 int16 word32 int32).each do |typ|
        alias_method "read_#{typ}_network", "read_#{typ}_big"
      end

      {:word16 => :uint16, :word32 => :uint32}.each do |old, new|
        ['_native', '_little', '_big', '_network'].each do |bo|
          alias_method "read_#{new}#{bo}", "read_#{old}#{bo}"
        end
      end

      # read exactly n characters, otherwise raise an exception.
      def readn(n)
        str = read(n)
        raise "couldn't read #{n} characters" if str.nil? or str.size != n
        str
      end

      private

      # shortcut method for readn+unpack
      def ru(size, template)
        readn(size).unpack(template).first
      end

      # same as method +ru+, but swap bytes if native byteorder == _byteorder_  
      def ru_swap(size, template, byteorder)
        str = readn(size)
        str.reverse! if ByteOrder.byteorder == byteorder 
        str.unpack(template).first
      end
    end
  end
end
