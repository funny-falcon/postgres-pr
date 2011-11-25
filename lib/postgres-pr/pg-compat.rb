# This is a compatibility layer for using the pure Ruby postgres-pr instead of
# the C interface of postgres.

require 'rexml/syncenumerator'
require 'postgres-pr/connection'
require 'postgres-pr/typeconv/conv'
require 'postgres-pr/typeconv/bytea'

class PGconn
  extend Postgres::Conversion
  include Postgres::Conversion
  PQTRANS_IDLE    = 0 #(connection idle)
  PQTRANS_INTRANS = 2 #(idle, within transaction block)
  PQTRANS_INERROR = 3 #(idle, within failed transaction)
  PQTRANS_UNKNOWN = 4 #(cannot determine status)

  class << self
    alias connect new
  end

  def initialize(host, port, options, tty, database, user, auth)
    uri =
    if host.nil?
      nil
    elsif host[0] != ?/
      "tcp://#{ host }:#{ port }"
    else
      "unix:#{ host }/.s.PGSQL.#{ port }"
    end
    @host = host
    @db = database
    @user = user
    @conn = PostgresPR::Connection.new(database, user, auth, uri)
  end

  def close
    @conn.close
  end

  alias finish close

  attr_reader :host, :db, :user

  def query(sql)
    PGresult.new(@conn.query(sql))
  end

  alias exec query
  alias async_exec exec

  def transaction_status
    @conn.transaction_status
  end

  def self.escape(str)
    str.gsub("'","''").gsub("\\", "\\\\\\\\")
  end

  def escape(str)
    self.class.escape(str)
  end
  
  if RUBY_VERSION < '1.9'
    def escape_string(str)
      case @conn.params['client_encoding'] 
      when /ASCII/, /ISO/, /KOI8/, /WIN/, /LATIN/
        def self.escape_string(str)
          str.gsub("'", "''").gsub("\\", "\\\\\\\\")
        end
      else
        def self.escape_string(str)
          str.gsub(/'/u, "''").gsub(/\\/u, "\\\\\\\\")
        end
      end
      escape_string(str)
    end
  else
    def escape_string(str)
      str.gsub("'", "''").gsub("\\", "\\\\\\\\")
    end
  end

  def notice_processor
    @conn.notice_processor
  end

  def notice_processor=(np)
    @conn.notice_processor = np
  end

  def self.quote_ident(name)
    %("#{name}")
  end

end

class PGresult
  include Enumerable

  EMPTY_QUERY = 0
  COMMAND_OK = 1
  TUPLES_OK = 2
  COPY_OUT = 3
  COPY_IN = 4
  BAD_RESPONSE = 5
  NONFATAL_ERROR = 6
  FATAL_ERROR = 7

  def each(&block)
    @result.each(&block)
  end

  def [](index)
    @result[index]
  end
  
  def initialize(res)
    @res = res
    @fields = @res.fields.map {|f| f.name}
    @result = []
    @res.rows.each do |row|
      h = {}
      @fields.zip(row){|field, value| h[field] = value}
      @result << h
    end
  end

  # TODO: status, cmdstatus
  
  def values
    @res.rows
  end
  
  def column_values(i)
    raise IndexError, "no column #{i} in result"  unless i < @fields.size
    @res.rows.map{|row| row[i]}
  end
  
  def field_values(field)
    raise IndexError, "no such field '#{field}' in result"  unless @fields.include?(field)
    @result.map{|row| row[field]}
  end

  attr_reader :result, :fields

  def num_tuples
    @result.size
  end

  alias :ntuples :num_tuples

  def num_fields
    @fields.size
  end

  alias :nfields :num_fields

  def fname(index)
    @fields[index]
  end
  
  alias fieldname fname
  
  def fnum(name)
    @fields.index(name)
  end
  
  alias fieldnum fnum

  def type(index)
    # TODO: correct?
    @res.fields[index].type_oid
  end
  
  alias :ftype :type

  def size(index)
    raise
    # TODO: correct?
    @res.fields[index].typlen
  end

  def getvalue(tup_num, field_num)
    @res.rows[tup_num][field_num]
  end
  
  def getlength(tup_num, field_num)
    @res.rows[typ_num][field_num].length
  end

  def status
    if num_tuples > 0
      TUPLES_OK
    else
      COMMAND_OK
    end
  end

  def cmdstatus
    @res.cmd_tag || ''
  end

  # free the result set
  def clear
    @res = @fields = @result = nil
  end

  # Returns the number of rows affected by the SQL command
  def cmdtuples
    case @res.cmd_tag
    when nil 
      return nil
    when /^INSERT\s+(\d+)\s+(\d+)$/, /^(DELETE|UPDATE|MOVE|FETCH)\s+(\d+)$/
      $2.to_i
    else
      nil
    end
  end
  
  alias :cmd_tuples :cmdtuples

end

class PGError < Exception
end
