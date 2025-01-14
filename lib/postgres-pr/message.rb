#
# Author:: Michael Neumann
# Copyright:: (c) 2005 by Michael Neumann
# License:: Same as Ruby's or BSD
# 

require 'postgres-pr/utils/buffer'
require 'postgres-pr/utils/byteorder'
class IO
  def read_exactly_n_bytes(n)
    buf = read(n)
    raise EOFError if buf == nil
    return buf if buf.size == n

    n -= buf.size

    while n > 0
      str = read(n)
      raise EOFError if str == nil
      buf << str
      n -= str.size 
    end
    return buf
  end
end


module PostgresPR

class PGError < StandardError; end
class ParseError < PGError; end
class DumpError < PGError; end


# Base class representing a PostgreSQL protocol message
class Message < Utils::ReadBuffer
  # One character message-typecode to class map
  MsgTypeMap = Hash.new { UnknownMessageType }

  def self.register_message_type(type)
    raise(PGError, "duplicate message type registration") if MsgTypeMap.has_key?(type)

    MsgTypeMap[type] = self

    self.const_set(:MsgType, type) 
    class_eval "def message_type; MsgType end"
  end

  def self.read(stream, startup=false)
    type = stream.read_exactly_n_bytes(1) unless startup
    length_s = stream.read_exactly_n_bytes(4)
    length = length_s.get_int32_network(0)  # FIXME: length should be signed, not unsigned

    raise ParseError unless length >= 4

    # initialize buffer
    body = stream.read_exactly_n_bytes(length - 4)
    (startup ? StartupMessage : MsgTypeMap[type]).create("#{type}#{length_s}#{body}")
  end

  def self.create(buffer)
    obj = allocate
    obj.init_buffer buffer
    obj.parse(obj)
    obj
  end

  def self.dump(*args)
    new(*args).dump
  end

  def buffer
    self
  end

  def dump(body_size=0)
    buffer = Utils::WriteBuffer.of_size(5 +  body_size)
    buffer.write(self.message_type)
    buffer.write_int32_network(4 + body_size)
    yield buffer if block_given?
    raise DumpError  unless buffer.at_end?
    buffer.content
  end

  def parse(buffer)
    buffer.position = 5
    yield buffer if block_given?
    raise ParseError, buffer.inspect unless buffer.at_end?
    buffer.close
  end

  def self.fields(*attribs)
    names = attribs.map {|name, type| name.to_s}
    arg_list = names.join(", ")
    ivar_list = names.map {|name| "@" + name }.join(", ")
    sym_list = names.map {|name| ":" + name }.join(", ")
    class_eval %[
      attr_accessor #{ sym_list } 
      def initialize(#{ arg_list })
        #{ ivar_list } = #{ arg_list }
      end
    ] 
  end
end

class UnknownMessageType < Message
  def dump
    raise PGError, "dumping unknown message"
  end
end

class Authentication < Message
  register_message_type 'R'

  AuthTypeMap = Hash.new { UnknownAuthType }

  def self.create(buffer)
    authtype = buffer.get_int32_network(5)
    klass = AuthTypeMap[authtype]
    obj = klass.allocate
    obj.init_buffer buffer
    obj.parse(obj)
    obj
  end

  def self.register_auth_type(type)
    raise(PGError, "duplicate auth type registration") if AuthTypeMap.has_key?(type)
    AuthTypeMap[type] = self
    self.const_set(:AuthType, type) 
    class_eval "def auth_type() AuthType end"
  end

  # the dump method of class Message
  alias message__dump dump

  def dump
    super(4) do |buffer|
      buffer.write_int32_network(self.auth_type)
    end
  end

  def parse(buffer)
    super do
      auth_t = buffer.read_int32_network 
      raise ParseError unless auth_t == self.auth_type
      yield if block_given?
    end
  end
end

class UnknownAuthType < Authentication
end

class AuthenticationOk < Authentication 
  register_auth_type 0
end

class AuthenticationKerberosV4 < Authentication 
  register_auth_type 1
end

class AuthenticationKerberosV5 < Authentication 
  register_auth_type 2
end

class AuthenticationClearTextPassword < Authentication 
  register_auth_type 3
end

module SaltedAuthenticationMixin
  attr_accessor :salt

  def initialize(salt)
    @salt = salt
  end

  def dump
    raise DumpError unless @salt.size == self.salt_size

    message__dump(4 + self.salt_size) do |buffer|
      buffer.write_int32_network(self.auth_type)
      buffer.write(@salt)
    end
  end

  def parse(buffer)
    super do
      @salt = buffer.read(self.salt_size)
    end
  end
end

class AuthenticationCryptPassword < Authentication 
  register_auth_type 4
  include SaltedAuthenticationMixin
  def salt_size; 2 end
end


class AuthenticationMD5Password < Authentication 
  register_auth_type 5
  include SaltedAuthenticationMixin
  def salt_size; 4 end
end

class AuthenticationSCMCredential < Authentication 
  register_auth_type 6
end

class PasswordMessage < Message
  register_message_type 'p'
  fields :password

  def dump
    super(@password.size + 1) do |buffer|
      buffer.write_cstring(@password)
    end
  end

  def parse(buffer)
    super do
      @password = buffer.read_cstring
    end
  end
end

class ParameterStatus < Message
  register_message_type 'S'
  fields :key, :value

  def dump
    super(@key.size + 1 + @value.size + 1) do |buffer|
      buffer.write_cstring(@key)
      buffer.write_cstring(@value)
    end
  end

  def parse(buffer)
    super do
      @key = buffer.read_cstring
      @value = buffer.read_cstring
    end
  end
end

class BackendKeyData < Message
  register_message_type 'K'
  fields :process_id, :secret_key

  def dump
    super(4 + 4) do |buffer|
      buffer.write_int32_network(@process_id)
      buffer.write_int32_network(@secret_key)
    end 
  end

  def parse(buffer)
    super do
      @process_id = buffer.read_int32_network
      @secret_key = buffer.read_int32_network
    end
  end
end

class ReadyForQuery < Message
  register_message_type 'Z'
  fields :backend_transaction_status_indicator

  def dump
    super(1) do |buffer|
      buffer.write_byte(@backend_transaction_status_indicator)
    end
  end

  def parse(buffer)
    super do
      @backend_transaction_status_indicator = buffer.read_byte
    end
  end
end

class DataRow < Message
  register_message_type 'D'
  fields :columns

  def dump
    sz = @columns.inject(2) {|sum, col| sum + 4 + (col ? col.size : 0)}
    super(sz) do |buffer|
      buffer.write_int16_network(@columns.size)
      @columns.each {|col|
        buffer.write_int32_network(col ? col.size : -1)
        buffer.write(col) if col
      }
    end
  end

  def parse(buffer)
    super do
      columns = []
      n_cols = buffer.read_int16_network
      while n_cols > 0
        len = buffer.read_int32_network 
        if len == -1
          columns << nil
        else
          columns << buffer.read(len)
        end
        n_cols -= 1
      end
      @columns = columns
    end
  end
end

class CommandComplete < Message
  register_message_type 'C'
  fields :cmd_tag

  def dump
    super(@cmd_tag.size + 1) do |buffer|
      buffer.write_cstring(@cmd_tag)
    end
  end

  def parse(buffer)
    super do
      @cmd_tag = buffer.read_cstring
    end
  end
end

class EmptyQueryResponse < Message
  register_message_type 'I'
end

module NoticeErrorMixin
  attr_accessor :field_type, :field_values

  def initialize(field_type=0, field_values=[])
    raise PGError if field_type == 0 and not field_values.empty?
    @field_type, @field_values = field_type, field_values
  end

  def dump
    raise PGError if @field_type == 0 and not @field_values.empty?

    sz = 1 
    sz += @field_values.inject(1) {|sum, fld| sum + fld.size + 1} unless @field_type == 0 

    super(sz) do |buffer|
      buffer.write_byte(@field_type)
      break if @field_type == 0 
      @field_values.each {|fld| buffer.write_cstring(fld) }
      buffer.write_byte(0)
    end
  end

  def parse(buffer)
    super do
      @field_type = buffer.read_byte
      break if @field_type == 0
      @field_values = []
      while buffer.position < buffer.size-1
        @field_values << buffer.read_cstring
      end
      terminator = buffer.read_byte
      raise ParseError unless terminator == 0
    end
  end
end

class NoticeResponse < Message
  register_message_type 'N'
  include NoticeErrorMixin
end

class ErrorResponse < Message
  register_message_type 'E'
  include NoticeErrorMixin
end

# TODO
class CopyInResponse < Message
  register_message_type 'G'
end

# TODO
class CopyOutResponse < Message
  register_message_type 'H'
end

class Parse < Message
  register_message_type 'P'
  fields :query, :stmt_name, :parameter_oids

  def initialize(query, stmt_name="", parameter_oids=[])
    @query, @stmt_name, @parameter_oids = query, stmt_name, parameter_oids
  end

  def dump
    sz = @stmt_name.size + 1 + @query.size + 1 + 2 + (4 * @parameter_oids.size)
    super(sz) do |buffer| 
      buffer.write_cstring(@stmt_name)
      buffer.write_cstring(@query)
      buffer.write_int16_network(@parameter_oids.size)
      @parameter_oids.each {|oid| buffer.write_int32_network(oid) }
    end
  end

  def parse(buffer)
    super do 
      @stmt_name = buffer.read_cstring
      @query = buffer.read_cstring
      n_oids = buffer.read_int16_network
      @parameter_oids = (1..n_oids).collect {
        # TODO: zero means unspecified. map to nil?
        buffer.read_int32_network
      }
    end
  end
end

class ParseComplete < Message
  register_message_type '1'
end

class Query < Message
  register_message_type 'Q'
  fields :query

  def dump
    super(@query.size + 1) do |buffer|
      buffer.write_cstring(@query)
    end
  end

  def parse(buffer)
    super do
      @query = buffer.read_cstring
    end
  end
end

class RowDescription < Message
  register_message_type 'T'
  fields :fields

  class FieldInfo < Struct.new(:name, :oid, :attr_nr, :type_oid, :typlen, :atttypmod, :formatcode); end

  def dump
    sz = @fields.inject(2) {|sum, fld| sum + 18 + fld.name.size + 1 }
    super(sz) do |buffer|
      buffer.write_int16_network(@fields.size)
      @fields.each { |f|
        buffer.write_cstring(f.name)
        buffer.write_int32_network(f.oid)
        buffer.write_int16_network(f.attr_nr)
        buffer.write_int32_network(f.type_oid)
        buffer.write_int16_network(f.typlen)
        buffer.write_int32_network(f.atttypmod)
        buffer.write_int16_network(f.formatcode)
      }
    end
  end

  if RUBY_ENGINE == 'rbx' || (RUBY_ENGINE == 'ruby' && RUBY_VERSION > '1.9' && Utils::STRING_NATIVE_UNPACK_SINGLE)
    def parse(buffer)
      super do
        fields = []
        n_fields = buffer.read_int16_network
        while n_fields > 0
          f = FieldInfo.new
          f.name       = buffer.read_cstring
          f.oid        = buffer.read_int32_network
          f.attr_nr    = buffer.read_int16_network
          f.type_oid   = buffer.read_int32_network
          f.typlen     = buffer.read_int16_network
          f.atttypmod  = buffer.read_int32_network
          f.formatcode = buffer.read_int16_network
          fields << f
          n_fields -= 1
        end
        @fields = fields
      end
    end
  elsif Utils::ByteOrder.little?
    def parse(buffer)
      super do
        fields = []
        n_fields = buffer.read_int16_network
        while n_fields > 0
          f = FieldInfo.new
          f.name       = buffer.read_cstring
          s = buffer.read(18); s.reverse!
          a = s.unpack('slslsl'); a.reverse!
          f.oid, f.attr_nr, f.type_oid, f.typlen, f.atttypmod, f.formatcode = a
          fields << f
          n_fields -= 1
        end
        @fields = fields
      end
    end
  else
    def parse(buffer)
      super do
        fields = []
        n_fields = buffer.read_int16_network
        while n_fields > 0
          f = FieldInfo.new
          f.name       = buffer.read_cstring
          a = buffer.read(18).unpack('lslsls')
          f.formatcode, f.atttypmod, f.typlen, f.type_oid, f.attr_nr, f.oid = a
          fields << f
          n_fields -= 1
        end
        @fields = fields
      end
    end
  end
end

class StartupMessage < Message
  fields :proto_version, :params

  def dump
    sz = @params.inject(4 + 4) {|sum, kv| sum + kv[0].size + 1 + kv[1].size + 1} + 1

    buffer = Utils::WriteBuffer.of_size(sz)
    buffer.write_int32_network(sz)
    buffer.write_int32_network(@proto_version)
    @params.each_pair {|key, value| 
      buffer.write_cstring(key)
      buffer.write_cstring(value)
    }
    buffer.write_byte(0)

    raise DumpError unless buffer.at_end?
    buffer.content
  end

  def parse(buffer)
    buffer.position = 4

    @proto_version = buffer.read_int32_network
    @params = {}

    while buffer.position < buffer.size-1
      key = buffer.read_cstring
      val = buffer.read_cstring
      @params[key] = val
    end

    nul = buffer.read_byte
    raise ParseError unless nul == 0
    raise ParseError unless buffer.at_end?
  end
end

class SSLRequest < Message
  fields :ssl_request_code

  def dump
    sz = 4 + 4
    buffer = Buffer.of_size(sz)
    buffer.write_int32_network(sz)
    buffer.write_int32_network(@ssl_request_code)
    raise DumpError unless buffer.at_end?
    return buffer.content
  end

  def parse(buffer)
    buffer.position = 4
    @ssl_request_code = buffer.read_int32_network
    raise ParseError unless buffer.at_end?
  end
end

=begin
# TODO: duplicate message-type, split into client/server messages
class Sync < Message
  register_message_type 'S'
end
=end

class Terminate < Message
  register_message_type 'X'
end

end # module PostgresPR
