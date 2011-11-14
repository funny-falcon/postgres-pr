module PostgresPR
  module Utils
    module ByteOrder 
      Native = :Native
      BigEndian = Big = Network = :BigEndian
      LittleEndian = Little = :LittleEndian

      # examines the byte order of the underlying machine
      if [0x12345678].pack("L") == "\x12\x34\x56\x78" 
        def byte_order
          BigEndian
        end

        def little_endian?
          false
        end

        def big_endian?
          true
        end
      else
        def byte_order
          LittleEndian
        end

        def little_endian?
          true
        end

        def big_endian?
          false
        end
      end

      alias byteorder byte_order 
      alias little? little_endian? 
      alias big? big_endian?
      alias network? big_endian?

      module_function :byte_order, :byteorder
      module_function :little_endian?, :little?
      module_function :big_endian?, :big?, :network?
    end
  end
end
