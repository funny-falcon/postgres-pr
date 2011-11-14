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
      # === Signed

      def read_int16_big
        # swap bytes if native=little (but we want big)
        yield2bytes{|b1, b2| (b1 < 128 ? b1 : b1 - 256) * 256 + b2}
      end

      # == 32 bit
      # === Signed

      def read_int32_big
        yield4bytes{|b1, b2, b3, b4| ((((b1 < 128 ? b1 : b1 - 256) * 256) + b2) * 256 + b3) * 256 + b4}
      end

      # == Aliases

      alias read_uint8 read_word8
      alias read_int16_network read_int16_big
      alias read_int32_network read_int32_big
    end
  end
end
